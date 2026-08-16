defmodule Canopy.Search.Backend do
  @moduledoc """
  Behaviour for workspace-search backends.

  Two implementations exist:

  - `Canopy.Search.Backend.Ripgrep` — shells out to `rg --json` (fast, default
    when the binary is on PATH).
  - `Canopy.Search.Backend.Elixir` — pure-Elixir fallback using `File.stream!/1`
    (slower, no external dependency).

  Implementations receive an absolute, validated `root_path` and return a list
  of match maps. Each match has the shape:

      %{
        file_path: binary,        # path RELATIVE to root_path (forward slashes)
        line_number: pos_integer,
        line_text: binary,        # may be truncated by the caller (>500 chars)
        match_start: non_neg_integer,
        match_end:   non_neg_integer
      }

  Backends MUST NOT return file_paths that escape `root_path`. The calling
  context (`Canopy.Search`) re-validates as defence-in-depth, but each
  backend is the first line of defence.
  """

  @type match :: %{
          file_path: binary(),
          line_number: pos_integer(),
          line_text: binary(),
          match_start: non_neg_integer(),
          match_end: non_neg_integer()
        }

  @type opts :: [
          regex: boolean(),
          case_sensitive: boolean(),
          limit: pos_integer(),
          include_glob: binary() | nil,
          exclude_glob: binary() | nil
        ]

  @callback search(root_path :: binary(), query :: binary(), opts :: opts()) ::
              {:ok, [match()]} | {:error, term()}
end
