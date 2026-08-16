defmodule Canopy.Runtimes.CodexLocal.Args do
  @moduledoc """
  CLI argument construction for the Codex Local adapter.

  Translates an execution context map into the list of flags passed to the
  `codex` binary.

  ## Codex exec invocation pattern

  Codex takes arguments in this shape:

      codex exec --json [--search] [--dangerously-bypass-approvals-and-sandbox]
           [--model <model>] [-c model_reasoning_effort=<effort>]
           [-c 'service_tier="fast"'] [-c features.fast_mode=true]
           [<extra_args>...]
           [resume <session_id>] -

  The prompt is written to stdin (`-` is the stdin sentinel). On resume,
  `resume <session_id>` is injected before the `-` sentinel.

  ## Fast mode (GPT-5.4 only)

  When `fast_mode` is enabled and the configured model is `gpt-5.4`, the
  adapter injects `service_tier="fast"` and `features.fast_mode=true` via `-c` flags.
  When the model is not `gpt-5.4`, fast_mode is silently ignored — the adapter
  logs a warning rather than failing the session.

  ## Session resume

  A session is eligible for resume when `external_session_id` is non-empty in
  the context map and the stored CWD matches the current CWD (or stored CWD
  is blank). Unlike Claude's triple-key resume, Codex does not use a
  prompt-bundle-key because it re-reads AGENTS.md from the repo on every exec.
  """

  require Logger

  @fast_mode_supported_models ["gpt-5.4"]

  @doc """
  Builds the CLI argument list for a `codex exec` invocation.

  `context` is the execution context map.

  Returns `{:ok, args}` where `args` is a list of strings ready to pass to
  `Port.open/2`.
  """
  @spec build(map()) :: {:ok, [String.t()]}
  def build(context) do
    model = Map.get(context, "model", "") |> to_string() |> String.trim()
    effort = Map.get(context, "model_reasoning_effort", "") |> to_string() |> String.trim()
    search = Map.get(context, "search", false)
    fast_mode = Map.get(context, "fast_mode", false)
    bypass = Map.get(context, "dangerously_bypass_approvals_and_sandbox", false)
    extra_args = Map.get(context, "extra_args", []) |> List.wrap()
    resume_id = resolve_resume_session_id(context)
    fast_mode_applied = fast_mode and model in @fast_mode_supported_models

    if fast_mode and not fast_mode_applied do
      Logger.warning(
        "[CodexLocal.Args] fast_mode requested but model=#{inspect(model)} " <>
          "is not supported (supported: #{Enum.join(@fast_mode_supported_models, ", ")}); ignoring"
      )
    end

    args =
      ["exec", "--json"]
      |> maybe_prepend(search, ["--search"])
      |> maybe_append(bypass, ["--dangerously-bypass-approvals-and-sandbox"])
      |> maybe_append(model != "", ["--model", model])
      |> maybe_append(effort != "", ["-c", "model_reasoning_effort=#{Jason.encode!(effort)}"])
      |> maybe_append(fast_mode_applied, [
        "-c",
        ~s(service_tier="fast"),
        "-c",
        "features.fast_mode=true"
      ])
      |> Kernel.++(extra_args)
      |> maybe_append(resume_id != nil, ["resume", resume_id || ""])
      |> Kernel.++(["-"])

    {:ok, args}
  end

  @doc """
  Checks the resume condition for a Codex session.

  Returns the `external_session_id` when it is present and the stored CWD
  matches the current CWD, or `nil` when the session cannot be resumed.

  Unlike Claude's triple-key resume, Codex does not require prompt-bundle-key
  matching because `codex exec` automatically discovers AGENTS.md from the repo.
  """
  @spec resolve_resume_session_id(map()) :: String.t() | nil
  def resolve_resume_session_id(context) do
    stored_id = Map.get(context, "external_session_id", "") |> to_string() |> String.trim()
    stored_cwd = Map.get(context, "stored_cwd", "") |> to_string() |> String.trim()
    current_cwd = Map.get(context, "cwd", "") |> to_string() |> String.trim()

    cwd_matches = stored_cwd == "" or Path.expand(stored_cwd) == Path.expand(current_cwd)

    if stored_id != "" and cwd_matches, do: stored_id, else: nil
  end

  @doc """
  Appends `extra` to `args` when `condition` is true; otherwise returns `args`
  unchanged.
  """
  @spec maybe_append([String.t()], boolean(), [String.t()]) :: [String.t()]
  def maybe_append(args, true, extra), do: args ++ extra
  def maybe_append(args, false, _extra), do: args

  # Prepends `extra` before all other args when condition is true.
  # Used for --search which must appear before `exec`.
  @spec maybe_prepend([String.t()], boolean(), [String.t()]) :: [String.t()]
  defp maybe_prepend(args, true, extra), do: extra ++ args
  defp maybe_prepend(args, false, _extra), do: args
end
