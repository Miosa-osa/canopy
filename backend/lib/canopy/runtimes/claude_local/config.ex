defmodule Canopy.Runtimes.ClaudeLocal.Config do
  @moduledoc """
  Declarative config schema for the Claude Local adapter.

  The schema is rendered by the Canopy frontend as a credential / settings form.
  Each field map mirrors the `ConfigFieldSchema` shape from Paperclip's
  `AdapterConfigSchema` type, adapted for Elixir atom keys.

  Fields:

  | key                           | type    | description                          |
  |-------------------------------|---------|--------------------------------------|
  | command                       | text    | Absolute or `$PATH` name for claude  |
  | model                         | select  | Default model override               |
  | effort                        | select  | Thinking effort (low/medium/high)    |
  | timeout_sec                   | number  | Per-session timeout; 0 = unlimited   |
  | dangerously_skip_permissions  | toggle  | Passes --dangerously-skip-permissions|
  """

  @doc """
  Returns the config schema as a list of field maps.
  """
  @spec schema() :: [map()]
  def schema do
    [
      %{
        key: "command",
        label: "Claude binary path",
        type: :text,
        required: false,
        placeholder: "claude",
        options: nil
      },
      %{
        key: "model",
        label: "Default model",
        type: :select,
        required: false,
        options: ["claude-sonnet-4-6", "claude-opus-4-7", "claude-haiku-4-5"],
        placeholder: nil
      },
      %{
        key: "effort",
        label: "Thinking effort",
        type: :select,
        required: false,
        options: ["low", "medium", "high"],
        placeholder: nil
      },
      %{
        key: "timeout_sec",
        label: "Timeout (seconds, 0 = unlimited)",
        type: :number,
        required: false,
        options: nil,
        placeholder: "0"
      },
      %{
        key: "dangerously_skip_permissions",
        label: "Skip permission prompts (--dangerously-skip-permissions)",
        type: :toggle,
        required: false,
        options: nil,
        placeholder: nil
      }
    ]
  end
end
