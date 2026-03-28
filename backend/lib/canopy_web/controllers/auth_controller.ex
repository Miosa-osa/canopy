defmodule CanopyWeb.AuthController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{User, Organization, OrganizationMembership, Workspace}
  alias Ecto.Multi
  import Ecto.Query

  def login(conn, %{"email" => email, "password" => password}) do
    user = Repo.one(from u in User, where: u.email == ^email)

    cond do
      user && Pbkdf2.verify_pass(password, user.password_hash) ->
        {:ok, token, _claims} =
          Canopy.Guardian.encode_and_sign(user, %{"role" => user.role}, ttl: {1, :hour})

        Repo.update!(
          Ecto.Changeset.change(user,
            last_login: DateTime.utc_now() |> DateTime.truncate(:second)
          )
        )

        json(conn, %{
          token: token,
          user: %{
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role
          }
        })

      true ->
        # Constant-time comparison to prevent user enumeration
        Pbkdf2.no_user_verify()

        conn
        |> put_status(401)
        |> json(%{error: "invalid_credentials"})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "invalid_request", details: "Missing email or password"})
  end

  def register(conn, %{"name" => _, "email" => _, "password" => password} = params)
      when byte_size(password) >= 8 do
    result =
      Multi.new()
      |> Multi.insert(:user, User.changeset(%User{}, params))
      |> Multi.insert(:organization, fn %{user: user} ->
        Organization.changeset(%Organization{}, %{
          name: "#{user.name}'s Organization"
        })
      end)
      |> Multi.insert(:membership, fn %{user: user, organization: org} ->
        OrganizationMembership.changeset(%OrganizationMembership{}, %{
          organization_id: org.id,
          user_id: user.id,
          role: "admin"
        })
      end)
      |> Multi.insert(:workspace, fn %{user: user, organization: org} ->
        Workspace.changeset(%Workspace{}, %{
          name: "Default Workspace",
          path: "/workspaces/default",
          owner_id: user.id,
          organization_id: org.id
        })
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{user: user, workspace: workspace}} ->
        {:ok, token, _claims} =
          Canopy.Guardian.encode_and_sign(user, %{"role" => user.role}, ttl: {1, :hour})

        conn
        |> put_status(201)
        |> json(%{
          token: token,
          user: %{
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role
          },
          workspace: %{
            id: workspace.id,
            name: workspace.name
          }
        })

      {:error, :user, changeset, _} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})

      {:error, step, changeset, _} ->
        conn
        |> put_status(422)
        |> json(%{error: "setup_failed", step: step, details: format_errors(changeset)})
    end
  end

  def register(conn, %{"password" => password}) when byte_size(password) < 8 do
    conn
    |> put_status(422)
    |> json(%{
      error: "validation_failed",
      details: %{password: ["must be at least 8 characters"]}
    })
  end

  def register(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "invalid_request", details: "Missing name, email, or password"})
  end

  def status(conn, _params) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- Canopy.Guardian.decode_and_verify(token),
         {:ok, user} <- Canopy.Guardian.resource_from_claims(claims) do
      json(conn, %{
        authenticated: true,
        user: %{
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role
        },
        expires_at: claims["exp"]
      })
    else
      _ ->
        json(conn, %{authenticated: false})
    end
  end

  def refresh(conn, _params) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, _old_claims} <- Canopy.Guardian.decode_and_verify(token),
         {:ok, _old_token, {new_token, new_claims}} <- Canopy.Guardian.refresh(token) do
      json(conn, %{token: new_token, expires_at: new_claims["exp"]})
    else
      _ ->
        conn
        |> put_status(401)
        |> json(%{error: "invalid_token"})
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
