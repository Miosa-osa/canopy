defmodule Canopy.Runtimes.GeminiLocal.Config do
  @moduledoc """
  Declarative config schema for the Gemini Local adapter.

  The schema is rendered by the Canopy frontend as a credential / settings form.
  Each field map follows the `ConfigFieldSchema` shape with Elixir atom keys.

  Fields:

  | key           | type   | description                                     |
  |---------------|--------|-------------------------------------------------|
  | command       | text   | Absolute or `$PATH` name for gemini binary      |
  | model         | select | Default model override (blank = auto)           |
  | api_key       | text   | GEMINI_API_KEY or GOOGLE_API_KEY override       |
  | sandbox       | toggle | Pass --sandbox to gemini (default: false)       |
  | timeout_sec   | number | Per-session timeout; 0 = unlimited              |
  """

  @doc """
  Returns the config schema as a list of field maps.
  """
  @spec schema() :: [map()]
  def schema do
    [
      %{
        key: "command",
        label: "Gemini binary path",
        type: :text,
        required: false,
        placeholder: "gemini",
        options: nil
      },
      %{
        key: "model",
        label: "Default model",
        type: :select,
        required: false,
        options: [
          "auto",
          "gemini-2.5-pro",
          "gemini-2.5-flash",
          "gemini-2.5-flash-lite",
          "gemini-2.0-flash",
          "gemini-2.0-flash-lite"
        ],
        placeholder: nil
      },
      %{
        key: "api_key",
        label: "Gemini API Key (GEMINI_API_KEY / GOOGLE_API_KEY)",
        type: :text,
        required: false,
        placeholder: "Leave blank to use CLI auth (gemini auth login)",
        options: nil
      },
      %{
        key: "sandbox",
        label: "Sandbox mode (--sandbox)",
        type: :toggle,
        required: false,
        options: nil,
        placeholder: nil
      },
      %{
        key: "timeout_sec",
        label: "Timeout (seconds, 0 = unlimited)",
        type: :number,
        required: false,
        options: nil,
        placeholder: "0"
      }
    ]
  end
end
