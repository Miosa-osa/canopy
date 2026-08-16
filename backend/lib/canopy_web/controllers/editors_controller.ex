defmodule CanopyWeb.EditorsController do
  @moduledoc """
  GET /api/v1/editors — returns locally installed code editors.

  Delegates detection to `Canopy.Editors.detect_editors/0`.
  """

  use CanopyWeb, :controller

  alias Canopy.Editors

  @doc "GET /api/v1/editors"
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    json(conn, %{data: Editors.detect_editors()})
  end
end
