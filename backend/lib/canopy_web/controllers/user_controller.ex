defmodule CanopyWeb.UserController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.User
  import Ecto.Query

  def index(conn, params) do
    current_user = conn.assigns.current_user

    if current_user.role != "admin" do
      conn |> put_status(403) |> json(%{error: "forbidden"})
    else
      role = params["role"]

      query = from u in User, order_by: [asc: u.name]
      query = if role, do: where(query, [u], u.role == ^role), else: query

      users = Repo.all(query)
      json(conn, %{users: Enum.map(users, &serialize/1)})
    end
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(User, id) do
      nil -> conn |> put_status(404) |> json(%{error: "not_found"})
      user -> json(conn, %{user: serialize(user)})
    end
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    if current_user.role != "admin" do
      conn |> put_status(403) |> json(%{error: "forbidden"})
    else
      changeset = User.changeset(%User{}, params)

      case Repo.insert(changeset) do
        {:ok, user} ->
          conn |> put_status(201) |> json(%{user: serialize(user)})

        {:error, changeset} ->
          conn
          |> put_status(422)
          |> json(%{error: "validation_failed", details: format_errors(changeset)})
      end
    end
  end

  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    if current_user.id != id && current_user.role != "admin" do
      conn |> put_status(403) |> json(%{error: "forbidden"})
    else
      case Repo.get(User, id) do
        nil ->
          conn |> put_status(404) |> json(%{error: "not_found"})

        user ->
          changeset = User.changeset(user, params)

          case Repo.update(changeset) do
            {:ok, updated} ->
              json(conn, %{user: serialize(updated)})

            {:error, changeset} ->
              conn
              |> put_status(422)
              |> json(%{error: "validation_failed", details: format_errors(changeset)})
          end
      end
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    if current_user.id != id && current_user.role != "admin" do
      conn |> put_status(403) |> json(%{error: "forbidden"})
    else
      case Repo.get(User, id) do
        nil ->
          conn |> put_status(404) |> json(%{error: "not_found"})

        user ->
          Repo.delete!(user)
          json(conn, %{ok: true})
      end
    end
  end

  defp serialize(%User{} = u) do
    %{
      id: u.id,
      name: u.name,
      email: u.email,
      role: u.role,
      provider: u.provider,
      last_login: u.last_login,
      inserted_at: u.inserted_at,
      updated_at: u.updated_at
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
