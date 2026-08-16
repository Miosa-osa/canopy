defmodule Canopy.Runtimes.CodexLocal.Config do
  @moduledoc """
  Declarative config schema for the Codex Local adapter.

  The schema is rendered by the Canopy frontend as a credential / settings form.
  Each field map follows the `ConfigFieldSchema` shape with Elixir atom keys.

  Fields:

  | key                                    | type    | description                             |
  |----------------------------------------|---------|-----------------------------------------|
  | command                                | text    | Absolute or `$PATH` name for codex      |
  | model                                  | select  | Default model override                  |
  | model_reasoning_effort                 | select  | Reasoning effort (minimal/low/medium/high/xhigh) |
  | timeout_sec                            | number  | Per-session timeout; 0 = unlimited      |
  | dangerously_bypass_approvals_and_sandbox | toggle | Passes --dangerously-bypass-approvals-and-sandbox |
  | search                                 | toggle  | Enables --search flag                   |
  | fast_mode                              | toggle  | Enables Fast mode (GPT-5.4 only)        |
  """

  @doc """
  Returns the config schema as a list of field maps.
  """
  @spec schema() :: [map()]
  def schema do
    [
      %{
        key: "command",
        label: "Codex binary path",
        type: :text,
        required: false,
        placeholder: "codex",
        options: nil
      },
      %{
        key: "model",
        label: "Default model",
        type: :select,
        required: false,
        options: [
          "gpt-5.4",
          "gpt-5.3-codex",
          "gpt-5.3-codex-spark",
          "gpt-5",
          "o3",
          "o4-mini",
          "gpt-5-mini",
          "gpt-5-nano",
          "o3-mini",
          "codex-mini-latest"
        ],
        placeholder: nil
      },
      %{
        key: "model_reasoning_effort",
        label: "Reasoning effort",
        type: :select,
        required: false,
        options: ["minimal", "low", "medium", "high", "xhigh"],
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
        key: "dangerously_bypass_approvals_and_sandbox",
        label: "Bypass approvals and sandbox (--dangerously-bypass-approvals-and-sandbox)",
        type: :toggle,
        required: false,
        options: nil,
        placeholder: nil
      },
      %{
        key: "search",
        label: "Enable web search (--search)",
        type: :toggle,
        required: false,
        options: nil,
        placeholder: nil
      },
      %{
        key: "fast_mode",
        label: "Fast mode (GPT-5.4 only — consumes credits faster)",
        type: :toggle,
        required: false,
        options: nil,
        placeholder: nil
      }
    ]
  end
end
