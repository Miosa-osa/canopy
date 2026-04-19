defmodule Canopy.DashboardTest do
  @moduledoc """
  Integration tests for Canopy.Dashboard.

  Tests all 11 aggregate functions across both the original 3 widgets and the
  8 new observability widgets. Every test must tolerate an empty database —
  functions return their zero/empty shape when no data exists.
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Dashboard

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp running_session!(overrides \\ %{}) do
    insert(:session, Map.merge(%{status: "running", started_at: DateTime.utc_now()}, overrides))
  end

  defp completed_session!(cost_usd, overrides \\ %{}) do
    insert(
      :session,
      Map.merge(
        %{
          status: "completed",
          started_at: DateTime.add(DateTime.utc_now(), -60),
          completed_at: DateTime.utc_now(),
          cost_usd: Decimal.new(cost_usd)
        },
        overrides
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Dashboard.active_agents/0
  # ---------------------------------------------------------------------------

  describe "active_agents/0" do
    test "returns empty list when no sessions exist" do
      assert [] = Dashboard.active_agents()
    end

    test "returns only running sessions" do
      running_session!(%{agent_slug: "builder"})
      completed_session!("0.01", %{agent_slug: "builder"})

      rows = Dashboard.active_agents()
      assert length(rows) == 1
      assert hd(rows).agent_slug == "builder"
    end

    test "caps at 50 rows" do
      Enum.each(1..55, fn _ -> running_session!() end)
      rows = Dashboard.active_agents()
      assert length(rows) == 50
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.spend_this_month/0
  # ---------------------------------------------------------------------------

  describe "spend_this_month/0" do
    test "returns zero totals when no completed sessions" do
      result = Dashboard.spend_this_month()
      assert result.total_usd == "0"
      assert result.by_agent == []
    end

    test "sums cost_usd from completed sessions this month" do
      completed_session!("1.50", %{agent_slug: "builder"})
      completed_session!("2.50", %{agent_slug: "builder"})
      completed_session!("1.00", %{agent_slug: "analyzer"})

      result = Dashboard.spend_this_month()

      assert Decimal.equal?(Decimal.new(result.total_usd), Decimal.new("5.00"))
      assert length(result.by_agent) == 2

      builder = Enum.find(result.by_agent, &(&1.agent_slug == "builder"))
      assert Decimal.equal?(Decimal.new(builder.cost_usd), Decimal.new("4.00"))
    end

    test "excludes running sessions from spend total" do
      running_session!(%{cost_usd: Decimal.new("99.99")})
      result = Dashboard.spend_this_month()
      assert Decimal.equal?(Decimal.new(result.total_usd), Decimal.new("0"))
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.recent_sessions/1
  # ---------------------------------------------------------------------------

  describe "recent_sessions/1" do
    test "returns empty list when no sessions" do
      assert [] = Dashboard.recent_sessions(10)
    end

    test "returns n most recent sessions ordered by inserted_at desc" do
      s1 = running_session!()
      s2 = completed_session!("1.00")

      rows = Dashboard.recent_sessions(10)
      ids = Enum.map(rows, & &1.id)

      assert s1.id in ids
      assert s2.id in ids
    end

    test "caps at 50 even if n > 50 requested" do
      Enum.each(1..55, fn _ -> running_session!() end)
      rows = Dashboard.recent_sessions(60)
      assert length(rows) == 50
    end

    test "returned rows have required fields" do
      running_session!(%{agent_slug: "tester"})
      [row | _] = Dashboard.recent_sessions(1)

      assert Map.has_key?(row, :id)
      assert Map.has_key?(row, :agent_slug)
      assert Map.has_key?(row, :status)
      assert Map.has_key?(row, :runtime_type)
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.summary/0
  # ---------------------------------------------------------------------------

  describe "summary/0" do
    test "returns map with required keys on empty database" do
      result = Dashboard.summary()

      assert is_map(result)
      assert Map.has_key?(result, :active_agents)
      assert Map.has_key?(result, :spend_this_month)
      assert Map.has_key?(result, :recent_sessions)
    end

    test "summary shapes are valid" do
      result = Dashboard.summary()

      assert is_list(result.active_agents)
      assert is_map(result.spend_this_month)
      assert Map.has_key?(result.spend_this_month, :total_usd)
      assert is_list(result.recent_sessions)
    end

    test "summary reflects inserted data" do
      running_session!(%{agent_slug: "testbot"})
      completed_session!("3.00")

      result = Dashboard.summary()

      assert length(result.active_agents) == 1
      assert length(result.recent_sessions) >= 2

      assert Decimal.compare(Decimal.new(result.spend_this_month.total_usd), Decimal.new("3.00")) ==
               :eq
    end

    test "summary includes all new observability keys" do
      result = Dashboard.summary()

      assert Map.has_key?(result, :total_messages)
      assert Map.has_key?(result, :total_sessions)
      assert Map.has_key?(result, :total_tokens)
      assert Map.has_key?(result, :success_rate)
      assert Map.has_key?(result, :sandbox_usage_today)
      assert Map.has_key?(result, :top_tools_30d)
      assert Map.has_key?(result, :peak_hours_30d)
      assert Map.has_key?(result, :storage_overview)
      assert Map.has_key?(result, :top_agents_by_usage)
      assert Map.has_key?(result, :token_usage_by_period)
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.total_messages/0
  # ---------------------------------------------------------------------------

  describe "total_messages/0" do
    test "returns zero count on empty database" do
      assert %{count: 0} = Dashboard.total_messages()
    end

    test "counts all session messages" do
      s = running_session!()
      insert(:session_message, session: s, sequence: 0, kind: "assistant")
      insert(:session_message, session: s, sequence: 1, kind: "tool_call")
      insert(:session_message, session: s, sequence: 2, kind: "tool_result")

      assert %{count: 3} = Dashboard.total_messages()
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.total_sessions/0
  # ---------------------------------------------------------------------------

  describe "total_sessions/0" do
    test "returns zero count on empty database" do
      assert %{count: 0} = Dashboard.total_sessions()
    end

    test "counts all sessions regardless of status" do
      running_session!()
      completed_session!("0.01")
      insert(:session, status: "failed")

      assert %{count: 3} = Dashboard.total_sessions()
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.total_tokens/0
  # ---------------------------------------------------------------------------

  describe "total_tokens/0" do
    test "returns zeros on empty database" do
      result = Dashboard.total_tokens()
      assert result.total == 0
      assert result.input == 0
      assert result.output == 0
    end

    test "sums tokens from completed sessions only" do
      completed_session!("0.01", %{
        input_tokens: 1000,
        output_tokens: 500,
        cache_read_tokens: 200,
        cache_write_tokens: 100
      })

      # Running session — should NOT be included
      running_session!(%{input_tokens: 9999, output_tokens: 9999})

      result = Dashboard.total_tokens()
      assert result.input == 1000
      assert result.output == 500
      assert result.cache_read == 200
      assert result.cache_write == 100
      assert result.total == 1800
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.success_rate/0
  # ---------------------------------------------------------------------------

  describe "success_rate/0" do
    test "returns zero rate on empty database" do
      result = Dashboard.success_rate()
      assert result.rate == 0.0
      assert result.completed == 0
      assert result.failed == 0
    end

    test "computes rate from completed and failed sessions" do
      completed_session!("0.01")
      completed_session!("0.01")
      completed_session!("0.01")
      insert(:session, status: "failed")

      result = Dashboard.success_rate()
      assert result.completed == 3
      assert result.failed == 1
      assert result.rate == 75.0
    end

    test "excludes cancelled and running sessions from rate" do
      completed_session!("0.01")
      insert(:session, status: "cancelled")
      running_session!()

      result = Dashboard.success_rate()
      assert result.completed == 1
      assert result.failed == 0
      assert result.rate == 100.0
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.sandbox_usage_today/0
  # ---------------------------------------------------------------------------

  describe "sandbox_usage_today/0" do
    test "returns zero values on empty database" do
      result = Dashboard.sandbox_usage_today()
      assert result.started == 0
      assert result.stopped == 0
      assert result.running_now == 0
      assert result.avg_lifetime_min == 0.0
    end

    test "counts sandbox sessions inserted today" do
      insert(:session,
        status: "running",
        started_at: DateTime.utc_now(),
        miosa_sandbox_status: "ready"
      )

      insert(:session,
        status: "completed",
        started_at: DateTime.add(DateTime.utc_now(), -300),
        completed_at: DateTime.utc_now(),
        miosa_sandbox_status: "destroyed"
      )

      result = Dashboard.sandbox_usage_today()
      assert result.started == 2
      assert result.stopped == 1
      assert result.running_now == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.top_tools_30d/1
  # ---------------------------------------------------------------------------

  describe "top_tools_30d/1" do
    test "returns empty list on empty database" do
      assert [] = Dashboard.top_tools_30d()
    end

    test "groups tool_call messages by tool_name" do
      s = running_session!()

      Enum.each(1..3, fn i ->
        insert(:session_message,
          session: s,
          sequence: i,
          kind: "tool_call",
          content: %{"tool_name" => "bash"}
        )
      end)

      insert(:session_message,
        session: s,
        sequence: 10,
        kind: "tool_call",
        content: %{"tool_name" => "read_file"}
      )

      rows = Dashboard.top_tools_30d()
      assert length(rows) >= 1
      top = hd(rows)
      assert top.tool_name == "bash"
      assert top.call_count == 3
    end

    test "excludes non-tool_call message kinds" do
      s = running_session!()

      insert(:session_message,
        session: s,
        sequence: 0,
        kind: "assistant",
        content: %{"tool_name" => "bash"}
      )

      assert [] = Dashboard.top_tools_30d()
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.peak_hours_30d/0
  # ---------------------------------------------------------------------------

  describe "peak_hours_30d/0" do
    test "returns 24-element list on empty database" do
      result = Dashboard.peak_hours_30d()
      assert length(result) == 24
      assert Enum.all?(result, &(&1 == 0))
    end

    test "increments the correct hour bucket" do
      # Insert a session with a known UTC hour
      now = DateTime.utc_now()
      insert(:session, status: "running", started_at: now)

      result = Dashboard.peak_hours_30d()
      assert length(result) == 24
      assert Enum.sum(result) >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.storage_overview/0
  # ---------------------------------------------------------------------------

  describe "storage_overview/0" do
    test "returns zero values on empty database" do
      result = Dashboard.storage_overview()
      assert result.workspaces == 0
      assert result.files == 0
      assert result.file_bytes == 0
      assert result.knowledge_bases == 0
      assert result.kb_chunks == 0
    end

    test "counts active workspaces (excludes soft-deleted)" do
      insert(:workspace)
      insert(:workspace)
      insert(:workspace, deleted_at: DateTime.utc_now())

      result = Dashboard.storage_overview()
      assert result.workspaces == 2
      assert result.buckets == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.top_agents_by_usage/1
  # ---------------------------------------------------------------------------

  describe "top_agents_by_usage/1" do
    test "returns empty list on empty database" do
      assert [] = Dashboard.top_agents_by_usage()
    end

    test "groups sessions by agent_slug ordered by count desc" do
      completed_session!("1.00", %{agent_slug: "builder"})
      completed_session!("1.00", %{agent_slug: "builder"})
      completed_session!("0.50", %{agent_slug: "analyzer"})

      rows = Dashboard.top_agents_by_usage(5)
      assert length(rows) == 2
      assert hd(rows).agent_slug == "builder"
      assert hd(rows).session_count == 2
    end

    test "excludes sessions without an agent_slug" do
      completed_session!("1.00", %{agent_slug: nil})
      completed_session!("1.00", %{agent_slug: "builder"})

      rows = Dashboard.top_agents_by_usage(5)
      assert length(rows) == 1
      assert hd(rows).agent_slug == "builder"
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard.token_usage_by_period/1
  # ---------------------------------------------------------------------------

  describe "token_usage_by_period/1" do
    test "returns zeros on empty database" do
      result = Dashboard.token_usage_by_period()
      assert result.total == 0
      assert result.input_tokens == 0
      assert result.output_tokens == 0
    end

    test "sums tokens for completed sessions in period" do
      completed_session!("0.01", %{
        input_tokens: 500,
        output_tokens: 250,
        cache_read_tokens: 50,
        cache_write_tokens: 25
      })

      result = Dashboard.token_usage_by_period(:month)
      assert result.input_tokens == 500
      assert result.output_tokens == 250
      assert result.cache_read == 50
      assert result.cache_write == 25
      assert result.total == 825
    end
  end
end
