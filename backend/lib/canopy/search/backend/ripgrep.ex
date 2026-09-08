defmodule Canopy.Search.Backend.Ripgrep do
  @moduledoc """
  Ripgrep-backed implementation of `Canopy.Search.Backend`.

  Spawns `rg --json` with a 5-second hard timeout, parses the JSONL stream
  line-by-line, and returns match maps. Paths returned by ripgrep are
  re-validated against `root_path` (defence-in-depth) before being surfaced.

  Flags honoured:

  - `:regex` (default `false`) — when false, passes `--fixed-strings` so the
    query is treated literally.
  - `:case_sensitive` (default `true`) — when false, passes `-i`.
  - `:limit` (default `200`) — applied as `--max-count <limit>` per file AND
    as a global cap on the response.
  - `:include_glob` — passed as `-g <glob>`.
  - `:exclude_glob` — passed as `-g !<glob>`.

  Ripgrep already honours `.gitignore` and skips hidden / binary files by
  default. We intentionally do NOT pass `--no-ignore`, `--hidden`, or
  `--binary` — that conservative posture is what keeps results signal-rich.
  """

  @behaviour Canopy.Search.Backend

  require Logger

  @timeout_ms 5_000

  @impl true
  def search(root_path, query, opts) when is_binary(root_path) and is_binary(query) do
    case System.find_executable("rg") do
      nil ->
        {:error, :ripgrep_not_available}

      rg_bin ->
        run(rg_bin, root_path, query, opts)
    end
  end

  # ---------------------------------------------------------------------------

  defp run(rg_bin, root_path, query, opts) do
    limit = Keyword.get(opts, :limit, 200)
    args = build_args(query, opts)

    parent = self()

    task =
      Task.async(fn ->
        try do
          # cd into root_path so paths in the JSON output are relative.
          {output, exit_code} =
            System.cmd(rg_bin, args, cd: root_path, stderr_to_stdout: true)

          send(parent, {:rg_done, exit_code, output})
        rescue
          err -> send(parent, {:rg_error, err})
        end
      end)

    receive do
      {:rg_done, 0, output} ->
        {:ok, parse_output(output, root_path, limit)}

      {:rg_done, 1, _output} ->
        # Exit code 1 = no matches found. Not an error.
        {:ok, []}

      {:rg_done, 2, output} ->
        # Exit code 2 = error (e.g. invalid regex).
        cond do
          String.contains?(output, "regex parse error") -> {:error, :invalid_regex}
          true -> {:error, {:ripgrep_error, String.trim(output)}}
        end

      {:rg_done, exit_code, output} ->
        Logger.warning("ripgrep exited with code #{exit_code}: #{inspect(output)}")
        {:error, {:ripgrep_error, "exit #{exit_code}"}}

      {:rg_error, err} ->
        {:error, {:ripgrep_error, Exception.message(err)}}
    after
      @timeout_ms ->
        Task.shutdown(task, :brutal_kill)
        {:error, :timeout}
    end
  end

  # ── Argument assembly ──────────────────────────────────────────────────────

  defp build_args(query, opts) do
    base = [
      "--json",
      "--line-number",
      "--column",
      "--no-heading",
      "--max-count",
      to_string(Keyword.get(opts, :limit, 200))
    ]

    base
    |> add_regex_flag(opts)
    |> add_case_flag(opts)
    |> add_glob(opts, :include_glob, & &1)
    |> add_glob(opts, :exclude_glob, &("!" <> &1))
    |> Kernel.++(["--", query, "."])
  end

  defp add_regex_flag(args, opts) do
    if Keyword.get(opts, :regex, false), do: args, else: args ++ ["--fixed-strings"]
  end

  defp add_case_flag(args, opts) do
    if Keyword.get(opts, :case_sensitive, true), do: args, else: args ++ ["-i"]
  end

  defp add_glob(args, opts, key, transform) do
    case Keyword.get(opts, key) do
      nil -> args
      "" -> args
      glob when is_binary(glob) -> args ++ ["-g", transform.(glob)]
    end
  end

  # ── Output parsing ─────────────────────────────────────────────────────────

  defp parse_output(output, root_path, limit) when is_binary(output) do
    output
    |> String.split("\n", trim: true)
    |> Stream.map(&decode_line/1)
    |> Stream.filter(&match?({:ok, %{"type" => "match"}}, &1))
    |> Stream.flat_map(fn {:ok, msg} -> matches_from_message(msg, root_path) end)
    |> Enum.take(limit)
  end

  defp decode_line(line) do
    case Jason.decode(line) do
      {:ok, msg} -> {:ok, msg}
      {:error, _} -> :skip
    end
  end

  defp matches_from_message(%{"data" => data}, root_path) do
    with %{"path" => %{"text" => rel_path}, "lines" => %{"text" => line_text}} <- data,
         line_number when is_integer(line_number) <- Map.get(data, "line_number"),
         submatches when is_list(submatches) <- Map.get(data, "submatches", []),
         true <- safe_path?(rel_path, root_path) do
      Enum.map(submatches, fn sm ->
        %{
          file_path: normalize_rel_path(rel_path),
          line_number: line_number,
          line_text: strip_trailing_newline(line_text),
          match_start: Map.get(sm, "start", 0),
          match_end: Map.get(sm, "end", 0)
        }
      end)
    else
      _ -> []
    end
  end

  defp matches_from_message(_, _), do: []

  # Defence-in-depth: ensure rg-reported path stays under root_path.
  defp safe_path?(rel_path, root_path) when is_binary(rel_path) do
    cond do
      String.starts_with?(rel_path, "/") ->
        false

      String.contains?(rel_path, "..") ->
        false

      true ->
        abs_root = Path.expand(root_path)
        abs = Path.expand(Path.join(abs_root, rel_path))
        String.starts_with?(abs, abs_root <> "/") or abs == abs_root
    end
  end

  defp safe_path?(_, _), do: false

  defp normalize_rel_path("./" <> rest), do: rest
  defp normalize_rel_path(path), do: path

  defp strip_trailing_newline(text) when is_binary(text) do
    text
    |> String.replace_suffix("\r\n", "")
    |> String.replace_suffix("\n", "")
  end

  defp strip_trailing_newline(other), do: other
end
