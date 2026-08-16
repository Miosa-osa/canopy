defmodule Canopy.Blocks.PostProcessor do
  @moduledoc """
  Thin wrapper around `Canopy.Sessions.Blocks.create/1` that runs the
  structured-output post-processing pass after every `agent_message` block.

  ## Hook point

  `Canopy.Sessions.Blocks` does not itself call the post-processor; the hook
  lives here so the blocks context stays focused on sequence management and
  CRUD. Callers that need auto-materialization should call
  `Canopy.Blocks.PostProcessor.create_block/2` instead of
  `Canopy.Sessions.Blocks.create/1` directly.

  Existing callers (relay, controllers, test helpers) that call the blocks
  context directly are unaffected — the post-processor is additive.

  ## Usage

      Canopy.Blocks.PostProcessor.create_block(attrs, session: session)

  Where `session` is a `%Canopy.Sessions.Session{}` with `:workspace_slug`,
  `:id`, and `:agent_slug` populated.
  """

  require Logger

  alias Canopy.Blocks.StructuredOutput
  alias Canopy.Sessions.Blocks

  @doc """
  Creates a block and, when its kind is `"agent_message"`, scans the content
  for structured markers and materializes any artifacts found.

  Returns `{:ok, block}` or `{:error, changeset}` — the same contract as
  `Canopy.Sessions.Blocks.create/1`. Materialization errors are logged but
  do not affect the return value; block persistence is always the primary
  concern.
  """
  @spec create_block(map(), keyword()) ::
          {:ok, Canopy.Sessions.Block.t()} | {:error, Ecto.Changeset.t()}
  def create_block(attrs, opts \\ []) do
    case Blocks.create(attrs) do
      {:ok, block} = result ->
        if block.kind == "agent_message" do
          run_post_process(block, opts[:session])
        end

        result

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp run_post_process(block, nil) do
    content = block.output_text || block.input_text || ""
    materialize_from_content(content, [])
  end

  defp run_post_process(block, session) do
    content = block.output_text || block.input_text || ""

    materialize_opts = [
      workspace_slug: session.workspace_slug,
      session_id: session.id,
      agent_slug: Map.get(session, :agent_slug)
    ]

    materialize_from_content(content, materialize_opts)
  end

  defp materialize_from_content(content, opts) do
    case StructuredOutput.parse(content) do
      [] ->
        :noop

      markers ->
        {:ok, artifacts} = StructuredOutput.materialize(markers, opts)

        errors = Enum.filter(artifacts, &(&1.type == :error))

        if errors != [] do
          Logger.warning(
            "[PostProcessor] #{length(errors)} artifact(s) failed to materialize: #{inspect(errors)}"
          )
        end

        {:ok, artifacts}
    end
  end
end
