defmodule Canopy.Tools.KanbanTest do
  @moduledoc """
  Tests for `Canopy.Tools.Kanban` MCP tool handlers.

  Exercises all four tools independently and verifies:
  - Ownership enforcement (agents can only touch their own claimed tasks)
  - PubSub broadcasts on claim/release/complete
  - `__canopy_tools__/0` declares the expected tool names
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Tasks.Kanban
  alias Canopy.Tools.Kanban, as: KanbanTools

  @workspace_slug "test-workspace"
  @agent_a "agent-alpha"
  @agent_b "agent-beta"

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  defp insert_task(attrs \\ []) do
    insert(:task, Keyword.merge([workspace_slug: @workspace_slug], attrs))
  end

  defp claim(task, agent_slug \\ @agent_a) do
    {:ok, claimed} = Kanban.claim_task(task.short_id, agent_slug)
    claimed
  end

  # ---------------------------------------------------------------------------
  # Tool declarations
  # ---------------------------------------------------------------------------

  describe "__canopy_tools__/0" do
    test "declares all four kanban tools" do
      names = KanbanTools.__canopy_tools__() |> Enum.map(& &1.name)

      assert "kanban.complete_task" in names
      assert "kanban.update_task" in names
      assert "kanban.add_note" in names
      assert "kanban.list_my_tasks" in names
    end
  end

  # ---------------------------------------------------------------------------
  # kanban.complete_task
  # ---------------------------------------------------------------------------

  describe "complete_task/1" do
    test "marks a claimed task as done" do
      task = insert_task() |> claim()

      assert {:ok, result} =
               KanbanTools.complete_task(%{
                 "task_id" => task.short_id,
                 "agent_slug" => @agent_a
               })

      assert result.status == "done"
      assert result.completed_at != nil
    end

    test "appends summary to description when provided" do
      task = insert_task(description: "Original description.") |> claim()

      assert {:ok, result} =
               KanbanTools.complete_task(%{
                 "task_id" => task.short_id,
                 "agent_slug" => @agent_a,
                 "summary" => "Finished the analysis."
               })

      assert result.description =~ "Original description."
      assert result.description =~ "[Summary] Finished the analysis."
    end

    test "returns not_your_task error when agent does not own the task" do
      task = insert_task() |> claim(@agent_a)

      assert {:error, :not_your_task} =
               KanbanTools.complete_task(%{
                 "task_id" => task.short_id,
                 "agent_slug" => @agent_b
               })
    end

    test "returns not_claimed error for an unclaimed task" do
      task = insert_task()

      assert {:error, :not_claimed} =
               KanbanTools.complete_task(%{
                 "task_id" => task.short_id,
                 "agent_slug" => @agent_a
               })
    end

    test "returns not_found for a non-existent task_id" do
      assert {:error, :not_found} =
               KanbanTools.complete_task(%{
                 "task_id" => "T-00000000",
                 "agent_slug" => @agent_a
               })
    end

    test "broadcasts kanban:completed on PubSub" do
      Phoenix.PubSub.subscribe(Canopy.PubSub, "tasks:workspace:#{@workspace_slug}")
      task = insert_task() |> claim()

      {:ok, _} =
        KanbanTools.complete_task(%{
          "task_id" => task.short_id,
          "agent_slug" => @agent_a
        })

      assert_receive %{event: "kanban:completed", task_id: task_id}
      assert task_id == task.id
    end
  end

  # ---------------------------------------------------------------------------
  # kanban.update_task
  # ---------------------------------------------------------------------------

  describe "update_task/1" do
    test "appends a status note to description" do
      task = insert_task(description: "Initial.") |> claim()

      assert {:ok, result} =
               KanbanTools.update_task(%{
                 "task_id" => task.short_id,
                 "agent_slug" => @agent_a,
                 "status_note" => "Half done."
               })

      assert result.description =~ "Initial."
      assert result.description =~ "[Update] Half done."
    end

    test "includes progress_pct in the note when provided" do
      task = insert_task() |> claim()

      assert {:ok, result} =
               KanbanTools.update_task(%{
                 "task_id" => task.short_id,
                 "agent_slug" => @agent_a,
                 "status_note" => "Almost there.",
                 "progress_pct" => 75
               })

      assert result.description =~ "[Progress 75%] Almost there."
    end

    test "returns not_your_task when agent does not own the task" do
      task = insert_task() |> claim(@agent_a)

      assert {:error, :not_your_task} =
               KanbanTools.update_task(%{
                 "task_id" => task.short_id,
                 "agent_slug" => @agent_b,
                 "status_note" => "Sneaky update."
               })
    end
  end

  # ---------------------------------------------------------------------------
  # kanban.add_note
  # ---------------------------------------------------------------------------

  describe "add_note/1" do
    test "appends a timestamped note to description" do
      task = insert_task(description: "Base.") |> claim()

      assert {:ok, result} =
               KanbanTools.add_note(%{
                 "task_id" => task.short_id,
                 "agent_slug" => @agent_a,
                 "note" => "Noticed a dependency."
               })

      assert result.description =~ "Base."
      assert result.description =~ "[Note "
      assert result.description =~ "Noticed a dependency."
    end

    test "works on a task with nil description" do
      task = insert_task(description: nil) |> claim()

      assert {:ok, result} =
               KanbanTools.add_note(%{
                 "task_id" => task.short_id,
                 "agent_slug" => @agent_a,
                 "note" => "First note."
               })

      assert result.description =~ "First note."
    end

    test "returns not_your_task when agent does not own the task" do
      task = insert_task() |> claim(@agent_a)

      assert {:error, :not_your_task} =
               KanbanTools.add_note(%{
                 "task_id" => task.short_id,
                 "agent_slug" => @agent_b,
                 "note" => "Unauthorized note."
               })
    end
  end

  # ---------------------------------------------------------------------------
  # kanban.list_my_tasks
  # ---------------------------------------------------------------------------

  describe "list_my_tasks/1" do
    test "returns only tasks claimed by the requesting agent" do
      task_a1 = insert_task() |> claim(@agent_a)
      task_a2 = insert_task() |> claim(@agent_a)
      _task_b = insert_task() |> claim(@agent_b)

      assert {:ok, %{count: 2, tasks: tasks}} =
               KanbanTools.list_my_tasks(%{"agent_slug" => @agent_a})

      ids = Enum.map(tasks, & &1.id)
      assert task_a1.id in ids
      assert task_a2.id in ids
    end

    test "returns empty list when agent has no claimed tasks" do
      assert {:ok, %{count: 0, tasks: []}} =
               KanbanTools.list_my_tasks(%{"agent_slug" => "agent-nobody"})
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub: Kanban.claim_task and Kanban.release_task
  # ---------------------------------------------------------------------------

  describe "PubSub broadcasts in Canopy.Tasks.Kanban" do
    test "claim_task broadcasts kanban:claimed" do
      Phoenix.PubSub.subscribe(Canopy.PubSub, "tasks:workspace:#{@workspace_slug}")
      task = insert_task()

      {:ok, _} = Kanban.claim_task(task.short_id, @agent_a)

      assert_receive %{event: "kanban:claimed", task_id: task_id, agent_slug: agent_slug}
      assert task_id == task.id
      assert agent_slug == @agent_a
    end

    test "release_task broadcasts kanban:released" do
      Phoenix.PubSub.subscribe(Canopy.PubSub, "tasks:workspace:#{@workspace_slug}")
      task = insert_task() |> claim(@agent_a)

      {:ok, _} = Kanban.release_task(task.short_id)

      assert_receive %{event: "kanban:released", task_id: task_id}
      assert task_id == task.id
    end

    test "complete_task broadcasts kanban:completed" do
      Phoenix.PubSub.subscribe(Canopy.PubSub, "tasks:workspace:#{@workspace_slug}")
      task = insert_task() |> claim(@agent_a)

      {:ok, _} = Kanban.complete_task(task.short_id)

      assert_receive %{event: "kanban:completed", task_id: task_id}
      assert task_id == task.id
    end

    test "no broadcast when task has no workspace_slug" do
      # Tasks without workspace_slug should not broadcast (no topic to broadcast on)
      Phoenix.PubSub.subscribe(Canopy.PubSub, "tasks:workspace:")
      task = insert(:task, workspace_slug: nil)

      {:ok, _} = Kanban.claim_task(task.short_id, @agent_a)

      refute_receive %{event: "kanban:claimed"}, 100
    end
  end
end
