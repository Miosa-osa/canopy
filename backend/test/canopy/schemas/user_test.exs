defmodule Canopy.Schemas.UserTest do
  use Canopy.DataCase

  alias Canopy.Schemas.User

  describe "changeset/2" do
    test "valid changeset with proper email" do
      changeset =
        User.changeset(%User{}, %{
          name: "Test User",
          email: "user@example.com",
          password: "securepass123"
        })

      assert changeset.valid?
    end

    test "rejects email with only @" do
      changeset =
        User.changeset(%User{}, %{
          name: "Test",
          email: "@",
          password: "securepass123"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:email]
    end

    test "rejects email without domain" do
      changeset =
        User.changeset(%User{}, %{
          name: "Test",
          email: "user@",
          password: "securepass123"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:email]
    end

    test "rejects email without TLD" do
      changeset =
        User.changeset(%User{}, %{
          name: "Test",
          email: "user@host",
          password: "securepass123"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:email]
    end

    test "rejects email with spaces" do
      changeset =
        User.changeset(%User{}, %{
          name: "Test",
          email: "user @example.com",
          password: "securepass123"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:email]
    end

    test "accepts email with subdomains" do
      changeset =
        User.changeset(%User{}, %{
          name: "Test",
          email: "user@mail.example.co.uk",
          password: "securepass123"
        })

      assert changeset.valid?
    end

    test "accepts email with plus tag" do
      changeset =
        User.changeset(%User{}, %{
          name: "Test",
          email: "user+tag@example.com",
          password: "securepass123"
        })

      assert changeset.valid?
    end

    test "rejects short password" do
      changeset =
        User.changeset(%User{}, %{
          name: "Test",
          email: "test@example.com",
          password: "short"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:password]
    end

    test "hashes password on valid changeset" do
      changeset =
        User.changeset(%User{}, %{
          name: "Test",
          email: "test@example.com",
          password: "securepass123"
        })

      assert changeset.valid?
      assert changeset.changes[:password_hash]
      assert changeset.changes[:password_hash] != "securepass123"
    end
  end

  # errors_on/1 is already imported from Canopy.DataCase
end
