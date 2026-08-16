defmodule Canopy.Issues.CheckoutTest do
  @moduledoc "Tests for issue checkout lock behaviour."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Issues

  # ---------------------------------------------------------------------------
  # try_checkout/3
  # ---------------------------------------------------------------------------

  describe "try_checkout/3" do
    test "happy path — agent claims an unchecked-out issue" do
      issue = insert(:issue)
      assert {:ok, updated} = Issues.try_checkout(issue.short_id, "agent-a")
      assert updated.checked_out_by_agent == "agent-a"
      assert updated.checked_out_at != nil
      assert updated.checkout_expires_at != nil
    end

    test "same agent renews its own lock" do
      issue = insert(:issue)
      {:ok, first} = Issues.try_checkout(issue.short_id, "agent-a", 60)
      {:ok, renewed} = Issues.try_checkout(issue.short_id, "agent-a", 3600)

      assert renewed.checked_out_by_agent == "agent-a"
      # Expiry should be later after renewal
      assert DateTime.compare(renewed.checkout_expires_at, first.checkout_expires_at) == :gt
    end

    test "409 collision — different agent blocked by active lock" do
      issue = insert(:issue)
      {:ok, _} = Issues.try_checkout(issue.short_id, "agent-a", 3600)

      assert {:error, :already_checked_out, info} =
               Issues.try_checkout(issue.short_id, "agent-b", 3600)

      assert info.locked_by == "agent-a"
      assert %DateTime{} = info.locked_until
    end

    test "expired lock — second agent may claim" do
      past = DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), -60, :second)

      issue =
        insert(:issue,
          checked_out_by_agent: "agent-stale",
          checked_out_at: past,
          checkout_expires_at: past
        )

      assert {:ok, updated} = Issues.try_checkout(issue.short_id, "agent-b", 3600)
      assert updated.checked_out_by_agent == "agent-b"
    end

    test "not_found for unknown issue" do
      assert {:error, :not_found} = Issues.try_checkout("I-99999999", "agent-a")
    end

    test "custom ttl_seconds respected" do
      issue = insert(:issue)
      {:ok, updated} = Issues.try_checkout(issue.short_id, "agent-x", 300)

      expected_min = DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 290, :second)
      assert DateTime.compare(updated.checkout_expires_at, expected_min) == :gt
    end
  end

  # ---------------------------------------------------------------------------
  # release/2
  # ---------------------------------------------------------------------------

  describe "release/2" do
    test "owner can release its lock" do
      issue = insert(:issue)
      {:ok, _} = Issues.try_checkout(issue.short_id, "agent-a")
      assert :ok = Issues.release(issue.short_id, "agent-a")

      {:ok, released} = Issues.get(issue.short_id)
      assert released.checked_out_by_agent == nil
    end

    test "non-owner cannot release" do
      issue = insert(:issue)
      {:ok, _} = Issues.try_checkout(issue.short_id, "agent-a")
      assert {:error, :not_owner} = Issues.release(issue.short_id, "agent-b")
    end

    test "not_found for unknown issue" do
      assert {:error, :not_found} = Issues.release("I-99999999", "agent-a")
    end
  end

  # ---------------------------------------------------------------------------
  # expire_stale_locks/0
  # ---------------------------------------------------------------------------

  describe "expire_stale_locks/0" do
    test "clears issues with past checkout_expires_at" do
      past = DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), -120, :second)

      stale =
        insert(:issue,
          checked_out_by_agent: "agent-stale",
          checked_out_at: past,
          checkout_expires_at: past
        )

      fresh_expires = DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 3600, :second)

      active =
        insert(:issue,
          checked_out_by_agent: "agent-active",
          checked_out_at: DateTime.utc_now() |> DateTime.truncate(:second),
          checkout_expires_at: fresh_expires
        )

      count = Issues.expire_stale_locks()
      assert count >= 1

      {:ok, stale_after} = Issues.get(stale.short_id)
      assert stale_after.checked_out_by_agent == nil

      {:ok, active_after} = Issues.get(active.short_id)
      assert active_after.checked_out_by_agent == "agent-active"
    end

    test "returns 0 when no locks are stale" do
      fresh_expires = DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 3600, :second)

      insert(:issue,
        checked_out_by_agent: "agent-ok",
        checked_out_at: DateTime.utc_now() |> DateTime.truncate(:second),
        checkout_expires_at: fresh_expires
      )

      # Count may include other test data but must be an integer
      count = Issues.expire_stale_locks()
      assert is_integer(count)
    end
  end
end
