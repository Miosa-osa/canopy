defmodule Canopy.Repo do
  use Ecto.Repo,
    otp_app: :canopy,
    adapter: Ecto.Adapters.Postgres
end
