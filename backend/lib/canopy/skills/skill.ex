defmodule Canopy.Skills.Skill do
  @moduledoc """
  Ecto schema for a Canopy skill.

  A skill is a markdown bundle stored in Postgres and injected into agent execution
  environments at runtime. The `provider_format` field controls which persona file
  the skill is injected into (CLAUDE.md, AGENTS.md, or a generic .agent_context path).

  The `content_hash` (SHA256) enables the Paperclip bundle-key optimization: if the
  hash matches the stored `prompt_bundle_key` on a session, skill injection is skipped,
  saving 5–10K tokens per heartbeat.

  Skills are importable from external registries (clawhub, skills_sh) or seeded locally
  from `priv/skills/`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @provider_formats ~w(claude agents_md generic)
  @sources ~w(local clawhub skills_sh user)

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :name,
             :description,
             :provider_format,
             :content,
             :content_hash,
             :source,
             :source_url,
             :imported_at,
             :tags,
             :enabled,
             :inserted_at,
             :updated_at
           ]}

  schema "skills" do
    field :slug, :string
    field :name, :string
    field :description, :string
    field :provider_format, :string, default: "generic"
    field :content, :string
    field :content_hash, :string
    field :source, :string, default: "local"
    field :source_url, :string
    field :imported_at, :utc_datetime_usec
    field :tags, {:array, :string}, default: []
    field :enabled, :boolean, default: true

    timestamps()
  end

  @required ~w(slug name content content_hash source provider_format)a
  @optional ~w(description source_url imported_at tags enabled)a

  @doc "Changeset for creating or updating a skill."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(skill, attrs) do
    skill
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, min: 1, max: 128)
    |> validate_format(:slug, ~r/\A[a-z0-9][a-z0-9\-]*[a-z0-9]\z|\A[a-z0-9]\z/)
    |> validate_length(:name, min: 1, max: 256)
    |> validate_inclusion(:provider_format, @provider_formats)
    |> validate_inclusion(:source, @sources)
    |> unique_constraint(:slug)
  end

  @doc "Returns the list of valid provider formats."
  @spec provider_formats() :: [String.t()]
  def provider_formats, do: @provider_formats

  @doc "Returns the list of valid sources."
  @spec sources() :: [String.t()]
  def sources, do: @sources
end
