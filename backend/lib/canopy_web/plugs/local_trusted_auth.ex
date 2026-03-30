defmodule CanopyWeb.Plugs.LocalTrustedAuth do
  @moduledoc """
  Bypass plug for local desktop development. When CANOPY_AUTH_MODE=local_trusted,
  assigns a synthetic admin user so API routes work without OAuth/JWT setup.

  Must be placed BEFORE the Auth plug in the :authenticated pipeline.
  In local_trusted mode, this plug assigns current_user and halts further auth checks.
  In any other mode, this plug is a no-op passthrough.
  """
  import Plug.Conn

  @local_user %{id: "local-admin", role: :admin, email: "local@canopy.local"}

  def init(opts), do: opts

  def call(conn, _opts) do
    if Application.get_env(:canopy, :auth_mode) == "local_trusted" do
      conn
      |> assign(:current_user, @local_user)
      |> assign(:claims, %{"sub" => "local-admin", "role" => "admin"})
      |> put_private(:guardian_default_resource, @local_user)
    else
      conn
    end
  end
end
