defmodule CanopyWeb.InvitationController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Invitation, OrganizationMembership}
  import Ecto.Query

  def index(conn, params) do
    organization_id = params["organization_id"]

    query =
      from i in Invitation,
        where: is_nil(i.accepted_at),
        order_by: [desc: i.inserted_at]

    query =
      if organization_id,
        do: where(query, [i], i.organization_id == ^organization_id),
        else: query

    invitations = Repo.all(query)
    json(conn, %{invitations: Enum.map(invitations, &serialize/1)})
  end

  def create(conn, params) do
    token = Base.encode16(:crypto.strong_rand_bytes(20), case: :lower)
    expires_at = DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60, :second)

    attrs =
      Map.merge(params, %{
        "token" => token,
        "expires_at" => expires_at
      })

    changeset = Invitation.changeset(%Invitation{}, attrs)

    case Repo.insert(changeset) do
      {:ok, invitation} ->
        conn |> put_status(201) |> json(%{invitation: serialize(invitation)})

      {:error, cs} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(cs)})
    end
  end

  def accept(conn, %{"token" => token}) do
    case Repo.one(from i in Invitation, where: i.token == ^token and is_nil(i.accepted_at)) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      invitation ->
        if invitation.expires_at &&
             DateTime.compare(invitation.expires_at, DateTime.utc_now()) == :lt do
          conn |> put_status(422) |> json(%{error: "invitation_expired"})
        else
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          user_id = conn.assigns[:current_user].id

          result =
            Repo.transaction(fn ->
              case invitation
                   |> Ecto.Changeset.change(accepted_at: now)
                   |> Repo.update() do
                {:ok, _} ->
                  if user_id do
                    %OrganizationMembership{}
                    |> OrganizationMembership.changeset(%{
                      "organization_id" => invitation.organization_id,
                      "user_id" => user_id,
                      "role" => invitation.role
                    })
                    |> Repo.insert(on_conflict: :nothing)
                  end

                {:error, changeset} ->
                  Repo.rollback(changeset)
              end
            end)

          case result do
            {:ok, _} ->
              json(conn, %{
                ok: true,
                organization_id: invitation.organization_id,
                role: invitation.role
              })

            {:error, _} ->
              conn |> put_status(500) |> json(%{error: "accept_failed"})
          end
        end
    end
  end

  # --- Private helpers ---

  defp serialize(%Invitation{} = i) do
    %{
      id: i.id,
      email: i.email,
      role: i.role,
      token: i.token,
      organization_id: i.organization_id,
      invited_by: i.invited_by,
      accepted_at: i.accepted_at,
      expires_at: i.expires_at,
      created_at: i.inserted_at,
      inserted_at: i.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
