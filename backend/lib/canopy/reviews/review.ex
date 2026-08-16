defmodule Canopy.Reviews.Review do
  @moduledoc """
  Ecto schema for a human-review request.

  Two kinds:
    - :artifact   — an agent-created doc/task/issue/pr/file/kb_chunk pending human approval
    - :tool_call  — a dangerous tool invocation (exec_shell, send_email, etc.) that must be
                    approved before the agent session proceeds

  Status lifecycle: pending → approved | rejected | changes_requested | expired

  Only `pending` reviews can be acted on. Any other transition is rejected (422).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_kinds ~w(artifact tool_call hire_agent)
  @valid_statuses ~w(pending approved rejected changes_requested expired)
  @terminal_statuses ~w(approved rejected changes_requested expired)

  @derive {Jason.Encoder,
           only: [
             :id,
             :workspace_slug,
             :kind,
             :artifact_type,
             :artifact_id,
             :artifact_preview,
             :tool_name,
             :tool_args,
             :session_id,
             :agent_id,
             :reviewer_id,
             :status,
             :feedback,
             :requested_at,
             :decided_at,
             :expires_at,
             :created_by_run_id,
             :revision_count,
             :inserted_at,
             :updated_at
           ]}

  schema "reviews" do
    field :workspace_slug, :string
    field :kind, :string, default: "artifact"

    # artifact fields
    field :artifact_type, :string
    field :artifact_id, :string
    field :artifact_preview, :string

    # tool_call fields
    field :tool_name, :string
    field :tool_args, :map

    # session context
    field :session_id, :binary_id
    field :agent_id, :string

    # decision fields
    field :reviewer_id, :string
    field :status, :string, default: "pending"
    field :feedback, :string
    field :requested_at, :utc_datetime
    field :decided_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :created_by_run_id, :binary_id
    field :revision_count, :integer, default: 0

    timestamps()
  end

  @required ~w(kind requested_at)a
  @optional ~w(workspace_slug artifact_type artifact_id artifact_preview
               tool_name tool_args session_id agent_id reviewer_id
               status feedback decided_at expires_at created_by_run_id revision_count)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(review, attrs) do
    review
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:kind, @valid_kinds)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_kind_fields()
  end

  @spec decision_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def decision_changeset(review, attrs) do
    review
    |> cast(attrs, [:status, :reviewer_id, :decided_at, :feedback])
    |> validate_required([:status, :decided_at])
    |> validate_inclusion(:status, @terminal_statuses)
    |> validate_pending_transition(review)
  end

  @doc """
  Changeset for resubmitting a review from changes_requested back to pending.
  Bumps revision_count and clears the decided_at timestamp.
  """
  @spec resubmit_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def resubmit_changeset(review, attrs \\ %{}) do
    review
    |> cast(attrs, [:artifact_preview])
    |> put_change(:status, "pending")
    |> put_change(:decided_at, nil)
    |> put_change(:revision_count, (review.revision_count || 0) + 1)
    |> validate_resubmit_transition(review)
  end

  # Enforce kind-specific required fields
  defp validate_kind_fields(changeset) do
    case get_field(changeset, :kind) do
      "tool_call" ->
        validate_required(changeset, [:tool_name])

      "hire_agent" ->
        validate_required(changeset, [:tool_name])

      "artifact" ->
        changeset

      _ ->
        changeset
    end
  end

  # Reject transitions from non-pending state
  defp validate_pending_transition(changeset, %{status: current_status}) do
    if current_status == "pending" do
      changeset
    else
      add_error(
        changeset,
        :status,
        "can only decide a pending review (currently #{current_status})"
      )
    end
  end

  # Resubmit is only valid from changes_requested
  defp validate_resubmit_transition(changeset, %{status: current_status}) do
    if current_status == "changes_requested" do
      changeset
    else
      add_error(
        changeset,
        :status,
        "can only resubmit a review in changes_requested state (currently #{current_status})"
      )
    end
  end
end
