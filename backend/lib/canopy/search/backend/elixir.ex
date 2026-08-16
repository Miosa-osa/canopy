defmodule Canopy.Search.Backend.Elixir do
  @moduledoc """
  Pure-Elixir fallback for `Canopy.Search.Backend`.

  Walks the workspace tree, skips binary + ignored directories, then
  streams each text file line-by-line and matches against the query
  (literal substring or regex).

  Slower than ripgrep — used only when `rg` is not available on PATH.
  Hard timeout: 10 seconds (configurable in test scenarios is unnecessary;
  callers set their own outer deadline if needed).

  Skipped automatically:

  - Hidden directories starting with `.` (except files inside the workspace
    root itself — files like `.gitignore` ARE searched).
  - Common build / dependency dirs: `node_modules`, `_build`, `deps`,
    `target`, `dist`, `.next`, `.git`, `.svelte-kit`.
  - Files that look binary (size 0, or first 512 bytes contain a NUL byte).
  - Files larger than 5 MB (read budget cap to keep latency bounded).
  """

  @behaviour Canopy.Search.Backend

  require Logger

  @timeout_ms 10_000
  @max_file_bytes 5 * 1024 * 1024
  @sniff_bytes 512
  @ignored_dirs ~w(.git node_modules _build deps target dist .next .svelte-kit .turbo .cache)

  @impl true
  def search(root_path, query, opts) when is_binary(root_path) and is_binary(query) do
    parent = self()

    task =
      Task.async(fn ->
        result = run(root_path, query, opts)
        send(parent, {:elixir_search_done, result})
      end)

    receive do
      {:elixir_search_done, result} -> result
    after
      @timeout_ms ->
        Task.shutdown(task, :brutal_kill)
        {:error, :timeout}
    end
  end

  # ---------------------------------------------------------------------------

  defp run(root_path, query, opts) do
    limit = Keyword.get(opts, :limit, 200)
    abs_root = Path.expand(root_path)

    case build_matcher(query, opts) do
      {:ok, matcher} ->
        matches =
          abs_root
          |> walk()
          |> Stream.flat_map(&matches_in_file(&1, abs_root, matcher, opts))
          |> Enum.take(limit)

        {:ok, matches}

      {:error, _} = err ->
        err
    end
  end

  # ── Matcher construction ───────────────────────────────────────────────────

  defp build_matcher(query, opts) do
    cond do
      Keyword.get(opts, :regex, false) ->
        regex_opts = if Keyword.get(opts, :case_sensitive, true), do: "", else: "i"

        case Regex.compile(query, regex_opts) do
          {:ok, re} -> {:ok, {:regex, re}}
          {:error, _} -> {:error, :invalid_regex}
        end

      true ->
        case_sensitive = Keyword.get(opts, :case_sensitive, true)
        {:ok, {:literal, query, case_sensitive}}
    end
  end

  # ── Filesystem walk ────────────────────────────────────────────────────────

  defp walk(abs_root) do
    Stream.resource(
      fn -> [abs_root] end,
      fn
        [] ->
          {:halt, nil}

        [dir | rest] ->
          case File.ls(dir) do
            {:ok, names} ->
              {files, dirs} =
                names
                |> Enum.map(&Path.join(dir, &1))
                |> Enum.split_with(&File.regular?/1)

              new_dirs =
                dirs
                |> Enum.filter(&File.dir?/1)
                |> Enum.reject(&ignored_dir?/1)

              {files, new_dirs ++ rest}

            {:error, _} ->
              {[], rest}
          end
      end,
      fn _ -> :ok end
    )
  end

  defp ignored_dir?(dir) do
    name = Path.basename(dir)

    cond do
      name in [".github"] -> false
      name in @ignored_dirs -> true
      String.starts_with?(name, ".") -> true
      true -> false
    end
  end

  # ── Per-file scan ──────────────────────────────────────────────────────────

  defp matches_in_file(abs_path, abs_root, matcher, opts) do
    rel_path = relative_to(abs_path, abs_root)

    cond do
      not glob_allowed?(rel_path, opts) ->
        []

      not text_file?(abs_path) ->
        []

      true ->
        scan(abs_path, rel_path, matcher)
    end
  rescue
    _ -> []
  end

  defp scan(abs_path, rel_path, matcher) do
    abs_path
    |> File.stream!([:read_ahead], :line)
    |> Stream.with_index(1)
    |> Stream.flat_map(fn {line, line_number} ->
      line = strip_trailing_newline(line)

      case match_line(line, matcher) do
        [] -> []
        ranges -> Enum.map(ranges, &to_match(rel_path, line_number, line, &1))
      end
    end)
  rescue
    _ -> []
  end

  defp to_match(rel_path, line_number, line, {start, length}) do
    %{
      file_path: rel_path,
      line_number: line_number,
      line_text: line,
      match_start: start,
      match_end: start + length
    }
  end

  # ── Match per line ─────────────────────────────────────────────────────────

  defp match_line(line, {:regex, re}) do
    Regex.scan(re, line, return: :index) |> Enum.map(&hd/1)
  end

  defp match_line(line, {:literal, query, true}) do
    find_all_byte_positions(line, query)
  end

  defp match_line(line, {:literal, query, false}) do
    find_all_byte_positions(String.downcase(line), String.downcase(query))
  end

  # Returns [{byte_offset, byte_length}, ...] for each occurrence.
  defp find_all_byte_positions(haystack, needle) when byte_size(needle) == 0, do: []

  defp find_all_byte_positions(haystack, needle) do
    do_find_all(haystack, needle, 0, [])
  end

  defp do_find_all(haystack, needle, offset, acc) do
    case :binary.match(haystack, needle) do
      :nomatch ->
        Enum.reverse(acc)

      {pos, len} ->
        absolute = offset + pos
        rest_offset = pos + len
        rest = binary_part(haystack, rest_offset, byte_size(haystack) - rest_offset)
        do_find_all(rest, needle, offset + rest_offset, [{absolute, len} | acc])
    end
  end

  # ── Globs ──────────────────────────────────────────────────────────────────

  defp glob_allowed?(rel_path, opts) do
    include = Keyword.get(opts, :include_glob)
    exclude = Keyword.get(opts, :exclude_glob)

    include_ok =
      case include do
        nil -> true
        "" -> true
        g -> match_glob?(rel_path, g)
      end

    exclude_ok =
      case exclude do
        nil -> true
        "" -> true
        g -> not match_glob?(rel_path, g)
      end

    include_ok and exclude_ok
  end

  # Lightweight `*`/`**` glob → regex translation. Sufficient for include/exclude
  # filters; anything more complex is handled by ripgrep when available.
  defp match_glob?(path, glob) do
    pattern =
      glob
      |> String.replace(".", "\\.")
      |> String.replace("**/", "(?:.*/)?")
      |> String.replace("**", ".*")
      |> String.replace("*", "[^/]*")
      |> String.replace("?", ".")

    case Regex.compile("\\A#{pattern}\\z") do
      {:ok, re} -> Regex.match?(re, path)
      _ -> false
    end
  end

  # ── Binary detection ───────────────────────────────────────────────────────

  defp text_file?(abs_path) do
    case :filelib.file_size(to_charlist(abs_path)) do
      0 ->
        false

      size when size > @max_file_bytes ->
        false

      _size ->
        not has_null_byte?(abs_path)
    end
  end

  defp has_null_byte?(abs_path) do
    case File.open(abs_path, [:read, :binary]) do
      {:ok, fd} ->
        try do
          case IO.binread(fd, @sniff_bytes) do
            data when is_binary(data) -> :binary.match(data, <<0>>) != :nomatch
            _ -> true
          end
        after
          File.close(fd)
        end

      _ ->
        true
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp relative_to(abs_path, abs_root) do
    case Path.relative_to(abs_path, abs_root) do
      ^abs_path -> abs_path
      rel -> rel
    end
  end

  defp strip_trailing_newline(line) when is_binary(line) do
    line
    |> String.replace_suffix("\r\n", "")
    |> String.replace_suffix("\n", "")
  end

  defp strip_trailing_newline(other), do: other
end
