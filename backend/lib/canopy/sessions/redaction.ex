defmodule Canopy.Sessions.Redaction do
  @moduledoc """
  Scrubs credential-shaped strings from transcript entries before persist + broadcast.

  Patterns detected (matching substrings replaced with a labelled sentinel):
    - AWS access keys:      AKIA[A-Z0-9]{16}
    - Anthropic keys:       sk-ant-[A-Za-z0-9-]{20,}  (checked before generic sk- pattern)
    - OpenAI / generic keys: sk-[A-Za-z0-9]{20,}
    - GitHub tokens:        gh[posu]_[A-Za-z0-9]{20,}
    - Google API keys:      AIza[A-Za-z0-9_-]{20,}
    - Bearer tokens:        Bearer [A-Za-z0-9._~+/-]{20,}={0,2}
    - Private key blocks:   -----BEGIN ... PRIVATE KEY----- ... -----END ... PRIVATE KEY-----
    - JWT:                  eyJ<header>.eyJ<payload>.<signature>

  Operates on arbitrary nested maps, lists, and tuples of strings. Integers,
  booleans, atoms, and nil pass through unchanged.

  Redaction is designed to be safe: any regex error returns the original string
  unchanged (false-negative over crash). Patterns are compiled once at module
  load via module attributes.
  """

  # Patterns are compiled at module load — no per-call Regex.compile overhead.
  # Anthropic key must precede the generic sk- pattern; more specific first.
  @patterns [
    {~r/AKIA[A-Z0-9]{16}/, "***REDACTED_AWS_KEY***"},
    {~r/sk-ant-[A-Za-z0-9\-]{20,}/, "***REDACTED_ANTHROPIC_KEY***"},
    {~r/sk-[A-Za-z0-9]{20,}/, "***REDACTED_API_KEY***"},
    {~r/gh[posu]_[A-Za-z0-9]{20,}/, "***REDACTED_GITHUB_TOKEN***"},
    {~r/AIza[A-Za-z0-9_\-]{20,}/, "***REDACTED_GOOGLE_KEY***"},
    {~r/Bearer\s+[A-Za-z0-9._~+\/\-]{20,}={0,2}/, "Bearer ***REDACTED***"},
    {~r/-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/,
     "***REDACTED_PRIVATE_KEY***"},
    {~r/eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}/,
     "***REDACTED_JWT***"}
  ]

  @doc """
  Walks any Elixir term and scrubs credential-shaped substrings from all binaries.

  Returns the same shape with credential values replaced by labelled sentinels.
  Non-string scalars (integers, booleans, atoms, nil) are returned unchanged.
  On any unexpected error, the original term is returned unchanged.
  """
  @spec scrub(term()) :: term()
  def scrub(term) do
    do_scrub(term)
  rescue
    _err -> term
  end

  # ---------------------------------------------------------------------------
  # Private recursive walker
  # ---------------------------------------------------------------------------

  defp do_scrub(value) when is_binary(value), do: scrub_string(value)

  # Structs (DateTime, Decimal, Ecto.UUID, etc.) are passed through unchanged.
  # Rebuilding a struct via Map.new/2 would drop the __struct__ key and break
  # the value; applying patterns to struct internals is also meaningless.
  defp do_scrub(%_{} = value), do: value

  defp do_scrub(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {do_scrub(k), do_scrub(v)} end)
  end

  defp do_scrub(value) when is_list(value) do
    Enum.map(value, &do_scrub/1)
  end

  defp do_scrub({a, b}), do: {do_scrub(a), do_scrub(b)}
  defp do_scrub({a, b, c}), do: {do_scrub(a), do_scrub(b), do_scrub(c)}

  defp do_scrub(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&do_scrub/1)
    |> List.to_tuple()
  end

  # Integers, floats, booleans, atoms, nil — pass through unchanged.
  defp do_scrub(value), do: value

  # Apply all patterns sequentially to a single string.
  # Each pattern's replacement is applied to the output of the previous, so
  # a string containing multiple credential types gets all of them redacted.
  defp scrub_string(str) do
    Enum.reduce(@patterns, str, fn {regex, replacement}, acc ->
      try do
        Regex.replace(regex, acc, replacement)
      rescue
        _err -> acc
      end
    end)
  end
end
