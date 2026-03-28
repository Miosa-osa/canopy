defmodule Canopy.Schemas.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "organizations" do
    field :name, :string
    field :slug, :string
    field :logo_url, :string
    field :plan, :string, default: "free"
    field :settings, :map, default: %{}
    field :mission, :string
    field :description, :string
    field :issue_prefix, :string
    field :budget_monthly_cents, :integer
    field :budget_per_agent_cents, :integer
    field :budget_enforcement, :string, default: "visibility"
    field :governance, :map, default: %{}

    has_many :memberships, Canopy.Schemas.OrganizationMembership
    has_many :invitations, Canopy.Schemas.Invitation
    has_many :divisions, Canopy.Schemas.Division
    has_many :workspaces, Canopy.Schemas.Workspace

    timestamps()
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [
      :name,
      :slug,
      :logo_url,
      :plan,
      :settings,
      :mission,
      :description,
      :issue_prefix,
      :budget_monthly_cents,
      :budget_per_agent_cents,
      :budget_enforcement,
      :governance
    ])
    |> validate_required([:name])
    |> maybe_generate_slug()
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
    |> validate_inclusion(:budget_enforcement, ~w(visibility warning stop))
    |> unique_constraint(:slug)
  end

  defp maybe_generate_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        name = get_field(changeset, :name) || ""
        suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)

        slug =
          name
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9]+/, "-")
          |> String.trim("-")

        put_change(changeset, :slug, "#{slug}-#{suffix}")

      _ ->
        changeset
    end
  end
end
