defmodule Canopy.Runtimes.ModelRole do
  @moduledoc """
  Per-model role assignment.

  A `(runtime, model)` pair can claim one or more roles from the canonical
  set. Multiple models may claim the same role; the `default_for_role` flag
  marks which one is active by default. The Runtime Adapter Agent reads
  this when dispatching role-specific work — chat goes to the chat default,
  edits go to the edit default, etc.

  ## Roles

  - `chat` — interactive Q&A.
  - `autocomplete` — inline keystroke completions.
  - `edit` — propose code edits in a diff format.
  - `apply` — fast-apply: take a proposed edit and write it to disk.
  - `embed` — produce vector embeddings.
  - `rerank` — rerank a candidate list.
  - `summarize` — terse summarization (cheap model recommended).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @roles ~w(chat autocomplete edit apply embed rerank summarize)

  @derive {Jason.Encoder,
           only: [
             :id,
             :runtime,
             :model,
             :role,
             :default_for_role,
             :priority,
             :workspace_slug,
             :metadata,
             :inserted_at,
             :updated_at
           ]}

  schema "runtime_model_roles" do
    field :runtime, :string
    field :model, :string
    field :role, :string
    field :default_for_role, :boolean, default: false
    field :priority, :integer, default: 0
    field :workspace_slug, :string
    field :metadata, :map, default: %{}

    timestamps()
  end

  @required ~w(runtime model role)a
  @optional ~w(default_for_role priority workspace_slug metadata)a

  @type t :: %__MODULE__{}

  @doc "Changeset for creating or updating a role assignment."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:role, @roles)
    |> validate_length(:runtime, max: 64)
    |> validate_length(:model, max: 128)
    |> unique_constraint([:runtime, :model, :role],
      name: :runtime_model_roles_unique_index
    )
  end

  @doc "All canonical roles."
  @spec roles() :: [String.t()]
  def roles, do: @roles
end
