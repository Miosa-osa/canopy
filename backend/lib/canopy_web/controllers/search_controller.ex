defmodule CanopyWeb.SearchController do
  @moduledoc """
  HTTP API for workspace-scoped line-level search.

  Routes:
    GET /api/v1/search
        ?q=...&workspace_slug=...&regex=true|false
        &case_sensitive=true|false&limit=...
        &include_glob=...&exclude_glob=...

  Powers the Build side rail's Search section. Results are line-level
  matches with character offsets so the frontend can highlight in place.
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Search
  alias CanopyWeb.Schemas.SearchSchema

  action_fallback CanopyWeb.FallbackController

  tags ["search"]

  @max_limit 1000
  @default_limit 200
  @max_query_len 512
  @slug_regex ~r/\A[a-z0-9][a-z0-9_-]{0,127}\z/

  operation :index,
    summary: "Search workspace files",
    description: """
    Runs a line-level search across all text files in the named workspace.
    Backend is ripgrep when available, pure Elixir otherwise. The chosen
    backend is reported in the response envelope.
    """,
    parameters: [
      q: [in: :query, type: :string, required: true, description: "Search query (1..512 chars)."],
      workspace_slug: [in: :query, type: :string, required: true],
      regex: [in: :query, type: :string, required: false],
      case_sensitive: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false],
      include_glob: [in: :query, type: :string, required: false],
      exclude_glob: [in: :query, type: :string, required: false]
    ],
    responses: [ok: {"Search result", "application/json", SearchSchema.SearchResult}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    with {:ok, query} <- validate_query(params["q"]),
         {:ok, slug} <- validate_slug(params["workspace_slug"]) do
      opts =
        [
          regex: parse_bool(params["regex"]) || false,
          case_sensitive: parse_case_sensitive(params["case_sensitive"]),
          limit: parse_limit(params["limit"])
        ]
        |> maybe_put(:include_glob, params["include_glob"])
        |> maybe_put(:exclude_glob, params["exclude_glob"])

      started = System.monotonic_time(:millisecond)

      case Search.search(query, slug, opts) do
        {:ok, %{matches: matches, backend: backend, truncated: truncated}} ->
          elapsed = System.monotonic_time(:millisecond) - started

          json(conn, %{
            data: matches,
            backend: Atom.to_string(backend),
            elapsed_ms: elapsed,
            truncated: truncated
          })

        {:error, :workspace_not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "workspace_not_found", workspace_slug: slug})

        {:error, :invalid_query} ->
          bad_request(conn, "invalid query")

        {:error, :invalid_regex} ->
          bad_request(conn, "invalid regex")

        {:error, :timeout} ->
          conn
          |> put_status(:request_timeout)
          |> json(%{error: "search_timeout"})

        {:error, :ripgrep_not_available} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "search_backend_unavailable"})

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "search_failed", message: safe_message(reason)})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  defp validate_query(nil), do: {:error, "q is required"}
  defp validate_query(""), do: {:error, "q cannot be empty"}

  defp validate_query(q) when is_binary(q) do
    cond do
      String.trim(q) == "" -> {:error, "q cannot be blank"}
      String.length(q) > @max_query_len -> {:error, "q exceeds #{@max_query_len} characters"}
      true -> {:ok, q}
    end
  end

  defp validate_query(_), do: {:error, "q must be a string"}

  defp validate_slug(nil), do: {:error, "workspace_slug is required"}
  defp validate_slug(""), do: {:error, "workspace_slug cannot be empty"}

  defp validate_slug(slug) when is_binary(slug) do
    if Regex.match?(@slug_regex, slug) do
      {:ok, slug}
    else
      {:error,
       "invalid workspace_slug: must be lowercase alphanumeric, dashes, underscores; max 128 chars; must start with letter or digit"}
    end
  end

  defp validate_slug(_), do: {:error, "workspace_slug must be a string"}

  # ---------------------------------------------------------------------------
  # Coercion
  # ---------------------------------------------------------------------------

  defp parse_bool(nil), do: nil
  defp parse_bool(""), do: nil
  defp parse_bool("true"), do: true
  defp parse_bool("1"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool("0"), do: false
  defp parse_bool(true), do: true
  defp parse_bool(false), do: false
  defp parse_bool(_), do: nil

  # case_sensitive defaults to TRUE when absent or unparseable.
  defp parse_case_sensitive(nil), do: true
  defp parse_case_sensitive(""), do: true

  defp parse_case_sensitive(v) do
    case parse_bool(v) do
      nil -> true
      bool -> bool
    end
  end

  defp parse_limit(nil), do: @default_limit
  defp parse_limit(""), do: @default_limit
  defp parse_limit(n) when is_integer(n) and n > 0, do: min(n, @max_limit)

  defp parse_limit(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, ""} when n > 0 -> min(n, @max_limit)
      _ -> @default_limit
    end
  end

  defp parse_limit(_), do: @default_limit

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  # ---------------------------------------------------------------------------
  # Errors
  # ---------------------------------------------------------------------------

  defp bad_request(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: to_string(reason)})
  end

  # Never leak internal error tuples to clients.
  defp safe_message({:ripgrep_error, msg}) when is_binary(msg), do: "search backend error"
  defp safe_message(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp safe_message(_), do: "internal error"
end
