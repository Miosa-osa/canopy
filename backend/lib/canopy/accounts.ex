defmodule Canopy.Accounts do
  @moduledoc "User management context."

  alias Canopy.Repo
  alias Canopy.Schemas.User
  import Ecto.Query

  def list_users(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    Repo.all(from u in User, order_by: [asc: u.name], limit: ^limit)
  end

  def get_user(id), do: Repo.get(User, id)
  def get_user!(id), do: Repo.get!(User, id)
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  def create_user(attrs) do
    %User{} |> User.changeset(attrs) |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user |> User.changeset(attrs) |> Repo.update()
  end

  def delete_user(%User{} = user), do: Repo.delete(user)

  def authenticate(email, password) do
    with %User{} = user <- get_user_by_email(email),
         true <- Pbkdf2.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      nil ->
        Pbkdf2.no_user_verify()
        {:error, :invalid_credentials}

      false ->
        {:error, :invalid_credentials}
    end
  end
end
