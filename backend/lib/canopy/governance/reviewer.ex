defmodule Canopy.Governance.Reviewer do
  @moduledoc """
  Hooks governance rules with `action: "require_review"` into artifact and
  tool-call create paths.

  ## Usage

      # Artifact path (Docs.create, Tasks.create, Issues.create)
      case Reviewer.maybe_request_review(:artifact, %{
        workspace_slug: "default",
        artifact_type: "doc",
        artifact_id: doc.id,
        artifact_preview: doc.title,
        agent_id: "my-agent",
        session_id: nil
      }) do
        {:review_pending, review_id} -> # mark entity as pending_review
        :no_review_required           -> # proceed normally
      end

      # Tool-call path (PTY dispatch)
      case Reviewer.maybe_request_review(:tool_call, %{
        session_id: sid,
        agent_id: "my-agent",
        tool_name: "exec_shell",
        tool_args: %{"command" => "rm -rf /"},
        workspace_slug: "default"
      }) do
        {:review_pending, review_id} -> {:error, :review_pending, review_id}
        :no_review_required          -> dispatch_tool()
      end

  ## Matching semantics

  A `:requires_review` rule fires when ALL of the following hold:

    - `conditions["match"]` equals the event kind ("artifact" or "tool_call").
    - `conditions["artifact_types"]` is nil/absent OR includes the artifact_type.
    - `conditions["tool_names"]`     is nil/absent OR includes the tool_name.
    - `conditions["agent_ids"]`      is nil/absent OR includes the agent_id.
    - `conditions["workspace_slugs"]` is nil/absent OR includes the workspace_slug.

  ## Fail-safe

  If `Reviews.request_artifact/1` or `Reviews.request_tool_call/3` returns an
  error, the reviewer logs the failure and returns `:no_review_required` so the
  caller can proceed. The human can re-request review manually later.
  """

  require Logger

  alias Canopy.Governance.RuleCache
  alias Canopy.Reviews

  @type artifact_attrs :: %{
          required(:workspace_slug) => String.t() | nil,
          required(:artifact_type) => String.t(),
          required(:artifact_id) => String.t() | nil,
          required(:artifact_preview) => String.t() | nil,
          required(:agent_id) => String.t() | nil,
          optional(:session_id) => String.t() | nil
        }

  @type tool_call_attrs :: %{
          required(:session_id) => String.t() | nil,
          required(:agent_id) => String.t() | nil,
          required(:tool_name) => String.t(),
          required(:tool_args) => map(),
          required(:workspace_slug) => String.t() | nil
        }

  @doc """
  Checks enabled `:requires_review` rules against an artifact being created.

  Returns `{:review_pending, review_id}` if any rule matches and a review was
  successfully created. Returns `:no_review_required` otherwise (including on
  Reviews error — fail-safe).
  """
  @spec maybe_request_review(:artifact, artifact_attrs()) ::
          {:review_pending, String.t()} | :no_review_required
  def maybe_request_review(:artifact, attrs) do
    artifact_type = Map.get(attrs, :artifact_type)
    agent_id = Map.get(attrs, :agent_id)
    workspace_slug = Map.get(attrs, :workspace_slug)

    matching_rule =
      RuleCache.list_enabled()
      |> Enum.find(fn rule ->
        rule.action == "require_review" and
          matches_artifact_conditions?(rule.conditions, artifact_type, agent_id, workspace_slug)
      end)

    case matching_rule do
      nil ->
        :no_review_required

      _rule ->
        review_attrs = %{
          workspace_slug: workspace_slug,
          artifact_type: artifact_type,
          artifact_id: Map.get(attrs, :artifact_id),
          artifact_preview: Map.get(attrs, :artifact_preview),
          agent_id: agent_id,
          session_id: Map.get(attrs, :session_id)
        }

        case Reviews.request_artifact(review_attrs) do
          {:ok, review} ->
            {:review_pending, review.id}

          {:error, reason} ->
            Logger.error(
              "[Reviewer] request_artifact failed for #{artifact_type}, proceeding: #{inspect(reason)}"
            )

            :no_review_required
        end
    end
  end

  @spec maybe_request_review(:tool_call, tool_call_attrs()) ::
          {:review_pending, String.t()} | :no_review_required
  def maybe_request_review(:tool_call, attrs) do
    tool_name = Map.get(attrs, :tool_name)
    agent_id = Map.get(attrs, :agent_id)
    workspace_slug = Map.get(attrs, :workspace_slug)

    matching_rule =
      RuleCache.list_enabled()
      |> Enum.find(fn rule ->
        rule.action == "require_review" and
          matches_tool_call_conditions?(rule.conditions, tool_name, agent_id, workspace_slug)
      end)

    case matching_rule do
      nil ->
        :no_review_required

      _rule ->
        session_id = Map.get(attrs, :session_id)
        tool_args = Map.get(attrs, :tool_args, %{})

        case Reviews.request_tool_call(session_id, tool_name, tool_args) do
          {:ok, review} ->
            {:review_pending, review.id}

          {:error, reason} ->
            Logger.error(
              "[Reviewer] request_tool_call failed for #{tool_name}, proceeding: #{inspect(reason)}"
            )

            :no_review_required
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private — condition matching
  # ---------------------------------------------------------------------------

  @spec matches_artifact_conditions?(map(), String.t() | nil, String.t() | nil, String.t() | nil) ::
          boolean()
  defp matches_artifact_conditions?(conditions, artifact_type, agent_id, workspace_slug) do
    Map.get(conditions, "match") == "artifact" and
      list_allows?(Map.get(conditions, "artifact_types"), artifact_type) and
      list_allows?(Map.get(conditions, "agent_ids"), agent_id) and
      list_allows?(Map.get(conditions, "workspace_slugs"), workspace_slug)
  end

  @spec matches_tool_call_conditions?(map(), String.t() | nil, String.t() | nil, String.t() | nil) ::
          boolean()
  defp matches_tool_call_conditions?(conditions, tool_name, agent_id, workspace_slug) do
    Map.get(conditions, "match") == "tool_call" and
      list_allows?(Map.get(conditions, "tool_names"), tool_name) and
      list_allows?(Map.get(conditions, "agent_ids"), agent_id) and
      list_allows?(Map.get(conditions, "workspace_slugs"), workspace_slug)
  end

  # nil means "all allowed"; a list means "must be in the list".
  @spec list_allows?(list() | nil, String.t() | nil) :: boolean()
  defp list_allows?(nil, _value), do: true
  defp list_allows?([], _value), do: true
  defp list_allows?(list, value) when is_list(list), do: value in list
end
