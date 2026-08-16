defmodule Canopy.Search do
  @moduledoc """
  Workspace-scoped line-level search context.

  Powers the Build side rail's Search section. Resolves a workspace by slug
  via `Canopy.Workspaces.get_by_slug/1`, picks a backend, runs the query,
  re-validates returned paths against the workspace root (defence-in-depth),
  and truncates excessively long match lines so the response stays bounded.

  Backend selection is governed by `:canopy, :search_backend`:

  - `:auto` (default) — `Canopy.Search.Backend.Ripgrep` if `rg` is on PATH,
    else `Canopy.Search.Backend.Elixir`.
  - `:ripgrep` — force ripgrep (errors if `rg` is missing).
  - `:elixir` — force the pure-Elixir backend.

  The chosen backend is logged at `:debug` so production operators can see
  which path served the request.

  ## Returns

      {:ok, %{matches: [match], backend: :ripgrep | :elixir, truncated: bool}}
      | {:error, reason}

  Errors:

  - `:workspace_not_found` — slug did not resolve.
  - `:invalid_query` — empty / out-of-range query.
  - `:invalid_regex` — regex flag set + query failed to compile.
  - `:timeout` — backend exceeded its hard deadline.
  - `:ripgrep_not_available` — backend was forced to `:ripgrep` but `rg` is missing.
  - other terms — unexpected backend failures.
  """

  require Logger

  alias Canopy.Search.Backend
  alias Canopy.Workspaces

  @max_query_len 512
  @max_limit 1_000
  @default_limit 200
  @line_truncate_at 500

  @type match :: Backend.match()
  @type backend_id :: :ripgrep | :elixir

  @type result :: %{matches: [match()], backend: backend_id(), truncated: boolean()}

  # ---------------------------------------------------------------------------

  @doc """
  Runs a workspace search.

  Required:
  - `query` — the search string. 1..512 characters.
  - `workspace_slug` — slug of an existing, non-deleted workspace.

  Options:
  - `:regex` (boolean, default false)
  - `:case_sensitive` (boolean, default true)
  - `:limit` (integer, capped at 1000, default 200)
  - `:include_glob` (binary)
  - `:exclude_glob` (binary)
  """
  @spec search(binary(), binary(), keyword()) :: {:ok, result()} | {:error, term()}
  def search(query, workspace_slug, opts \\ [])

  def search(query, workspace_slug, opts)
      when is_binary(query) and is_binary(workspace_slug) do
    with :ok <- validate_query(query),
         {:ok, workspace} <- Workspaces.get_by_slug(workspace_slug),
         backend <- pick_backend(),
         normalized_opts <- normalize_opts(opts),
         _ <- log_backend(backend, workspace_slug),
         {:ok, raw_matches} <- backend.search(workspace.root_path, query, normalized_opts) do
      {matches, truncated_any?} =
        raw_matches
        |> Enum.filter(&safe_match?(&1, workspace.root_path))
        |> Enum.map_reduce(false, fn m, acc ->
          {truncated, line} = maybe_truncate_line(m.line_text)
          {%{m | line_text: line}, acc or truncated}
        end)

      {:ok,
       %{
         matches: matches,
         backend: backend_id(backend),
         truncated: truncated_any?
       }}
    end
  end

  def search(_, _, _), do: {:error, :invalid_query}

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  defp validate_query(""), do: {:error, :invalid_query}

  defp validate_query(q) when is_binary(q) do
    trimmed = String.trim(q)

    cond do
      trimmed == "" -> {:error, :invalid_query}
      String.length(q) > @max_query_len -> {:error, :invalid_query}
      true -> :ok
    end
  end

  defp validate_query(_), do: {:error, :invalid_query}

  # ---------------------------------------------------------------------------
  # Backend selection
  # ---------------------------------------------------------------------------

  defp pick_backend do
    case Application.get_env(:canopy, :search_backend, :auto) do
      :ripgrep -> Backend.Ripgrep
      :elixir -> Backend.Elixir
      :auto -> auto_pick()
      mod when is_atom(mod) -> mod
    end
  end

  defp auto_pick do
    if System.find_executable("rg"), do: Backend.Ripgrep, else: Backend.Elixir
  end

  defp backend_id(Backend.Ripgrep), do: :ripgrep
  defp backend_id(Backend.Elixir), do: :elixir
  defp backend_id(_), do: :unknown

  defp log_backend(backend, slug) do
    Logger.debug(fn ->
      "Canopy.Search: backend=#{inspect(backend)} workspace=#{slug}"
    end)
  end

  # ---------------------------------------------------------------------------
  # Options
  # ---------------------------------------------------------------------------

  defp normalize_opts(opts) do
    [
      regex: !!Keyword.get(opts, :regex, false),
      case_sensitive: !!Keyword.get(opts, :case_sensitive, true),
      limit: clamp_limit(Keyword.get(opts, :limit, @default_limit)),
      include_glob: opt_string(Keyword.get(opts, :include_glob)),
      exclude_glob: opt_string(Keyword.get(opts, :exclude_glob))
    ]
  end

  defp clamp_limit(n) when is_integer(n) and n > 0, do: min(n, @max_limit)
  defp clamp_limit(_), do: @default_limit

  defp opt_string(nil), do: nil
  defp opt_string(""), do: nil
  defp opt_string(s) when is_binary(s), do: s
  defp opt_string(_), do: nil

  # ---------------------------------------------------------------------------
  # Defence-in-depth path validation
  # ---------------------------------------------------------------------------

  defp safe_match?(%{file_path: rel_path}, root_path)
       when is_binary(rel_path) and is_binary(root_path) do
    cond do
      String.starts_with?(rel_path, "/") -> false
      String.contains?(rel_path, "..") -> false
      true ->
        abs_root = Path.expand(root_path)
        abs = Path.expand(Path.join(abs_root, rel_path))
        String.starts_with?(abs, abs_root <> "/") or abs == abs_root
    end
  end

  defp safe_match?(_, _), do: false

  # ---------------------------------------------------------------------------
  # Line truncation
  # ---------------------------------------------------------------------------

  defp maybe_truncate_line(line) when is_binary(line) do
    if String.length(line) > @line_truncate_at do
      truncated = String.slice(line, 0, @line_truncate_at) <> "…"
      {true, truncated}
    else
      {false, line}
    end
  end

  defp maybe_truncate_line(other), do: {false, other}
end
