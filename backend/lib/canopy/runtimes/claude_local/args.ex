defmodule Canopy.Runtimes.ClaudeLocal.Args do
  @moduledoc """
  CLI argument construction for the Claude Local adapter.

  Translates an execution context map into the list of flags passed to the
  `claude` binary.  Implements two Paperclip-derived optimisations:

  ## Triple-key resume (Paperclip pattern)

  A session is eligible for `--resume` only when three stored keys all match
  the current context:

  1. `external_session_id` — Claude's own session UUID from the previous run.
  2. `cwd` — the working directory must be identical (or stored CWD is blank).
  3. `prompt_bundle_key` — the SHA-256 of agent markdown + skills must match
     (or stored key is blank).

  When all three match, `resolve_resume_session_id/2` returns the session ID
  to pass to `--resume`.

  ## Skip `--append-system-prompt-file` on resume

  When resuming an existing session, Claude already has the system prompt in its
  context cache.  Omitting `--append-system-prompt-file` saves 5–10K tokens per
  heartbeat.  The flag is only appended on *new* sessions.
  """

  @doc """
  Builds the CLI argument list for a `claude` invocation.

  `context` is the execution context map.  `prompt_bundle_key` is the
  SHA-256 hex produced by `Canopy.Runtimes.Bundle.compute_key/2`.

  Returns `{:ok, args}` where `args` is a list of strings ready to pass to
  `Port.open/2`.
  """
  @spec build(map(), String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def build(context, prompt_bundle_key) do
    model = Map.get(context, "model", "") |> to_string() |> String.trim()
    effort = Map.get(context, "effort", "") |> to_string() |> String.trim()
    max_turns = Map.get(context, "max_turns", 0)

    instructions_file =
      Map.get(context, "instructions_file_path", "") |> to_string() |> String.trim()

    skip_perms = Map.get(context, "dangerously_skip_permissions", false)
    extra_args = Map.get(context, "extra_args", []) |> List.wrap()
    resume_id = resolve_resume_session_id(context, prompt_bundle_key)

    args =
      ["--print", "-", "--output-format", "stream-json", "--verbose"]
      |> maybe_append(resume_id != nil, ["--resume", resume_id || ""])
      |> maybe_append(skip_perms, ["--dangerously-skip-permissions"])
      |> maybe_append(model != "", ["--model", model])
      |> maybe_append(effort != "", ["--effort", effort])
      |> maybe_append(max_turns > 0, ["--max-turns", Integer.to_string(max_turns)])
      # Skip --append-system-prompt-file on resume — saves 5–10K tokens per heartbeat.
      # Paperclip: "On resumed sessions the instructions are already in the session cache."
      |> maybe_append(instructions_file != "" and resume_id == nil, [
        "--append-system-prompt-file",
        instructions_file
      ])
      |> Kernel.++(extra_args)

    {:ok, args}
  end

  @doc """
  Checks the triple-key resume condition.

  Returns the `external_session_id` to pass to `--resume` when all three keys
  match, or `nil` when any key is missing or mismatched.
  """
  @spec resolve_resume_session_id(map(), String.t()) :: String.t() | nil
  def resolve_resume_session_id(context, prompt_bundle_key) do
    stored_id = Map.get(context, "external_session_id", "") |> to_string() |> String.trim()
    stored_cwd = Map.get(context, "stored_cwd", "") |> to_string() |> String.trim()
    stored_key = Map.get(context, "stored_prompt_bundle_key", "") |> to_string() |> String.trim()
    current_cwd = Map.get(context, "cwd", "") |> to_string() |> String.trim()

    cwd_matches = stored_cwd == "" or Path.expand(stored_cwd) == Path.expand(current_cwd)
    key_matches = stored_key == "" or stored_key == prompt_bundle_key

    if stored_id != "" and cwd_matches and key_matches, do: stored_id, else: nil
  end

  @doc """
  Appends `extra` to `args` when `condition` is true; otherwise returns `args`
  unchanged.
  """
  @spec maybe_append([String.t()], boolean(), [String.t()]) :: [String.t()]
  def maybe_append(args, true, extra), do: args ++ extra
  def maybe_append(args, false, _extra), do: args
end
