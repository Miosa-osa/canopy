defmodule CanopyWeb.Plugs.LocalTrustedAuth do
  @moduledoc """
  Bypasses JWT authentication in local_trusted mode for desktop development.

  When CANOPY_AUTH_MODE=local_trusted, injects a synthetic admin user into
  conn.assigns so that downstream plugs (WorkspaceAuth, Governance, etc.)
  have a current_user with the expected fields (.id, .role, .email).

  The Auth plug checks for an existing current_user assignment and skips
  its JWT verification when this plug has already populated it.

  This plug is a no-op in all other auth modes.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if Application.get_env(:canopy, :auth_mode) == "local_trusted" do
      local_user_id =
        Application.get_env(:canopy, :local_trusted_user_id, "00000000-0000-0000-0000-000000000001")

      local_user = %{
        id: local_user_id,
        role: :admin,
        email: "local@canopy.local",
        name: "Local Admin"
      }

      conn
      |> assign(:current_user, local_user)
      |> assign(:claims, %{"sub" => local_user_id, "typ" => "access"})
      |> put_private(:guardian_default_resource, local_user)
    else
      conn
    end
  end
end
