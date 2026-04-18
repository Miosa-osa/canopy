defmodule Canopy.MiosaTest do
  @moduledoc """
  Tests for the Canopy.Miosa public API.

  Uses Mox to mock Canopy.Miosa.MockClient (configured in test.exs via
  `config :canopy, :miosa_client, Canopy.Miosa.MockClient`).

  MIOSA API URL/key are set to non-empty values per test when testing the
  "configured" path; left empty (the test.exs default) for "not configured" tests.
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory
  import Mox

  alias Canopy.Miosa
  alias Canopy.Sessions

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # configured?/0
  # ---------------------------------------------------------------------------

  describe "configured?/0" do
    test "returns false when URL and key are empty strings (default test.exs)" do
      refute Miosa.configured?()
    end

    test "returns false when only URL is set" do
      Application.put_env(:canopy, :miosa_api_url, "http://miosa.example.com")
      Application.put_env(:canopy, :miosa_api_key, "")

      refute Miosa.configured?()
    after
      Application.put_env(:canopy, :miosa_api_url, "")
      Application.put_env(:canopy, :miosa_api_key, "")
    end

    test "returns true when both URL and key are set" do
      Application.put_env(:canopy, :miosa_api_url, "http://miosa.example.com")
      Application.put_env(:canopy, :miosa_api_key, "test-api-key-abc123")

      assert Miosa.configured?()
    after
      Application.put_env(:canopy, :miosa_api_url, "")
      Application.put_env(:canopy, :miosa_api_key, "")
    end
  end

  # ---------------------------------------------------------------------------
  # provision_for_session/2
  # ---------------------------------------------------------------------------

  describe "provision_for_session/2" do
    test "returns {:error, :not_found} for unknown session_id" do
      assert {:error, :not_found} = Miosa.provision_for_session(Ecto.UUID.generate())
    end

    test "sets miosa_sandbox_status to 'skipped' when MIOSA not configured" do
      # Default test.exs: miosa_api_url = "" → configured?() == false
      session = insert(:session)

      assert {:ok, updated} = Miosa.provision_for_session(session.id)
      assert updated.miosa_sandbox_status == "skipped"
      assert updated.miosa_sandbox_id == nil
    end

    test "provisions sandbox and returns updated session when configured" do
      session = insert(:session)
      set_miosa_configured()

      Mox.expect(Canopy.Miosa.MockClient, :provision_sandbox, fn _opts ->
        {:ok,
         %{sandbox_id: "sbx-abc123", url: "https://sbx.miosa.dev/abc123", status: "provisioning"}}
      end)

      assert {:ok, updated} = Miosa.provision_for_session(session.id)
      assert updated.miosa_sandbox_id == "sbx-abc123"
      assert updated.miosa_sandbox_url == "https://sbx.miosa.dev/abc123"
      assert updated.miosa_sandbox_status == "provisioning"
    after
      clear_miosa_config()
    end

    test "sets miosa_sandbox_status to 'failed' on client error" do
      session = insert(:session)
      set_miosa_configured()

      Mox.expect(Canopy.Miosa.MockClient, :provision_sandbox, fn _opts ->
        {:error, :timeout}
      end)

      assert {:ok, updated} = Miosa.provision_for_session(session.id)
      assert updated.miosa_sandbox_status == "failed"
    after
      clear_miosa_config()
    end

    test "passes opts to client" do
      session = insert(:session)
      set_miosa_configured()

      Mox.expect(Canopy.Miosa.MockClient, :provision_sandbox, fn opts ->
        assert opts[:template] == "gpu-vm"
        assert opts[:ttl_seconds] == 7200
        {:ok, %{sandbox_id: "sbx-gpu", url: "https://sbx.miosa.dev/gpu", status: "provisioning"}}
      end)

      assert {:ok, _updated} =
               Miosa.provision_for_session(session.id, template: "gpu-vm", ttl_seconds: 7200)
    after
      clear_miosa_config()
    end
  end

  # ---------------------------------------------------------------------------
  # mark_ready/1
  # ---------------------------------------------------------------------------

  describe "mark_ready/1" do
    test "returns {:error, :not_found} when no session has that sandbox_id" do
      assert {:error, :not_found} = Miosa.mark_ready("sbx-nonexistent")
    end

    test "transitions sandbox_status to 'ready' and broadcasts PubSub" do
      session = insert(:session)

      # Manually set sandbox fields
      {:ok, provisioning} =
        Sessions.get(session.id)
        |> then(fn {:ok, s} -> s end)
        |> Canopy.Sessions.Session.sandbox_changeset(%{
          miosa_sandbox_id: "sbx-test-ready",
          miosa_sandbox_url: "https://sbx.miosa.dev/test",
          miosa_sandbox_status: "provisioning"
        })
        |> Canopy.Repo.update()

      Phoenix.PubSub.subscribe(Canopy.PubSub, "session:#{provisioning.id}")

      assert {:ok, updated} = Miosa.mark_ready("sbx-test-ready")
      assert updated.miosa_sandbox_status == "ready"

      assert_receive {:sandbox_ready, %{sandbox_id: "sbx-test-ready"}}
    end
  end

  # ---------------------------------------------------------------------------
  # destroy_for_session/1
  # ---------------------------------------------------------------------------

  describe "destroy_for_session/1" do
    test "returns {:error, :not_found} for unknown session_id" do
      assert {:error, :not_found} = Miosa.destroy_for_session(Ecto.UUID.generate())
    end

    test "returns {:ok, session} without API call when no sandbox is attached" do
      session = insert(:session)
      # No mock expectations set — no client call should happen
      assert {:ok, returned} = Miosa.destroy_for_session(session.id)
      assert returned.id == session.id
    end

    test "calls destroy_sandbox and updates status to 'destroyed'" do
      session = insert(:session)
      set_miosa_configured()

      {:ok, provisioned} =
        Sessions.get(session.id)
        |> then(fn {:ok, s} -> s end)
        |> Canopy.Sessions.Session.sandbox_changeset(%{
          miosa_sandbox_id: "sbx-to-destroy",
          miosa_sandbox_url: "https://sbx.miosa.dev/destroy",
          miosa_sandbox_status: "ready"
        })
        |> Canopy.Repo.update()

      Mox.expect(Canopy.Miosa.MockClient, :destroy_sandbox, fn "sbx-to-destroy" -> :ok end)

      assert {:ok, destroyed} = Miosa.destroy_for_session(provisioned.id)
      assert destroyed.miosa_sandbox_status == "destroyed"
    after
      clear_miosa_config()
    end

    test "still marks destroyed even when MIOSA returns :not_found (already gone)" do
      session = insert(:session)
      set_miosa_configured()

      {:ok, provisioned} =
        Sessions.get(session.id)
        |> then(fn {:ok, s} -> s end)
        |> Canopy.Sessions.Session.sandbox_changeset(%{
          miosa_sandbox_id: "sbx-already-gone",
          miosa_sandbox_url: "https://sbx.miosa.dev/gone",
          miosa_sandbox_status: "provisioning"
        })
        |> Canopy.Repo.update()

      Mox.expect(Canopy.Miosa.MockClient, :destroy_sandbox, fn _ -> {:error, :not_found} end)

      assert {:ok, destroyed} = Miosa.destroy_for_session(provisioned.id)
      assert destroyed.miosa_sandbox_status == "destroyed"
    after
      clear_miosa_config()
    end
  end

  # ---------------------------------------------------------------------------
  # get_sandbox_status/1
  # ---------------------------------------------------------------------------

  describe "get_sandbox_status/1" do
    test "returns nil for unknown session" do
      assert nil == Miosa.get_sandbox_status(Ecto.UUID.generate())
    end

    test "returns nil when no sandbox has been provisioned" do
      session = insert(:session)
      assert nil == Miosa.get_sandbox_status(session.id)
    end

    test "returns the sandbox status string" do
      session = insert(:session)

      {:ok, _} =
        Sessions.get(session.id)
        |> then(fn {:ok, s} -> s end)
        |> Canopy.Sessions.Session.sandbox_changeset(%{
          miosa_sandbox_id: "sbx-status-check",
          miosa_sandbox_status: "ready"
        })
        |> Canopy.Repo.update()

      assert Miosa.get_sandbox_status(session.id) == "ready"
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp set_miosa_configured do
    Application.put_env(:canopy, :miosa_api_url, "http://miosa.test")
    Application.put_env(:canopy, :miosa_api_key, "test-key")
  end

  defp clear_miosa_config do
    Application.put_env(:canopy, :miosa_api_url, "")
    Application.put_env(:canopy, :miosa_api_key, "")
  end
end
