defmodule Canopy.Runtimes.GeminiLocal.Args do
  @moduledoc """
  CLI argument construction for the Gemini Local adapter.

  Translates an execution context map into the list of flags passed to the
  `gemini` binary. Key differences from the Claude adapter:

  ## Prompt delivery — positional `--prompt` flag

  Gemini CLI does not read a prompt from stdin. The prompt is passed as a
  positional argument via `--prompt "<text>"`. The Runner does NOT write to the
  Port's stdin after spawn.

  ## Session resume

  Gemini supports `--resume <session_id>`. The session ID comes from a previous
  run's stream output (`session_id` field). Resume eligibility is checked against
  the stored CWD — if the CWD doesn't match, the session is not resumed (Gemini
  sessions are CWD-scoped).

  Unlike Claude's triple-key check, Gemini uses a dual-key check:
  1. `external_session_id` — Gemini's session ID from the previous run.
  2. `cwd` — must match (or stored CWD is blank).

  There is no `prompt_bundle_key` optimisation for Gemini — the instructions
  file is always inlined into the prompt prefix on new sessions.

  ## Sandbox mode

  Gemini accepts `--sandbox` (enable) or `--sandbox=none` (disable). Canopy
  defaults to `--sandbox=none` (disabled) unless `context["sandbox"]` is true.

  ## Approval mode

  Gemini requires `--approval-mode yolo` for unattended / non-interactive
  execution. Canopy always sets this flag.
  """

  @doc """
  Builds the CLI argument list for a `gemini` invocation.

  Returns `{:ok, args}` where `args` is a list of strings ready to pass to
  `Port.open/2`. The prompt is embedded in the args list — the Runner must
  NOT write to stdin.
  """
  @spec build(map()) :: {:ok, [String.t()]} | {:error, term()}
  def build(context) do
    model = Map.get(context, "model", "") |> to_string() |> String.trim()
    sandbox = Map.get(context, "sandbox", false)
    extra_args = Map.get(context, "extra_args", []) |> List.wrap()
    prompt = Map.get(context, "prompt", "") |> to_string()
    resume_id = resolve_resume_session_id(context)

    args =
      ["--output-format", "stream-json", "--approval-mode", "yolo"]
      |> maybe_append(resume_id != nil, ["--resume", resume_id || ""])
      |> maybe_append(model != "" and model != "auto", ["--model", model])
      |> append_sandbox(sandbox)
      |> Kernel.++(extra_args)
      # Prompt is always last — Gemini CLI requires --prompt at the end
      |> maybe_append(prompt != "", ["--prompt", prompt])

    {:ok, args}
  end

  @doc """
  Checks the dual-key resume condition for Gemini.

  Returns the `external_session_id` to pass to `--resume` when both keys
  match, or `nil` when any key is missing or mismatched.

  Gemini sessions are CWD-scoped: if the stored CWD doesn't match the current
  CWD, the session cannot be resumed (Gemini will 404 the checkpoint).
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

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec append_sandbox([String.t()], boolean()) :: [String.t()]
  defp append_sandbox(args, true), do: args ++ ["--sandbox"]
  defp append_sandbox(args, _sandbox), do: args ++ ["--sandbox=none"]
end
