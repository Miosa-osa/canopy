defmodule CanopyWeb.EditorsControllerTest do
  @moduledoc """
  Tests for GET /api/v1/editors.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Editors

  describe "GET /api/v1/editors" do
    test "returns 200 with a list of editor entries", %{conn: conn} do
      conn = get(conn, "/api/v1/editors")

      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
      assert length(data) > 0
    end

    test "each entry has command, name, and installed keys", %{conn: conn} do
      conn = get(conn, "/api/v1/editors")

      assert %{"data" => data} = json_response(conn, 200)

      Enum.each(data, fn entry ->
        assert is_binary(entry["command"])
        assert is_binary(entry["name"])
        assert is_boolean(entry["installed"])
      end)
    end
  end

  describe "detect_editors/0" do
    test "returns a list" do
      result = Editors.detect_editors()
      assert is_list(result)
    end

    test "each entry has command, name, and installed keys" do
      result = Editors.detect_editors()

      Enum.each(result, fn entry ->
        assert is_binary(entry.command)
        assert is_binary(entry.name)
        assert is_boolean(entry.installed)
      end)
    end

    test "vim is detected as installed on this machine" do
      result = Editors.detect_editors()
      vim = Enum.find(result, &(&1.command == "vim"))
      assert vim != nil
      # vim is installed on the dev machine (standard UNIX tool)
      assert vim.installed == true
    end
  end
end
