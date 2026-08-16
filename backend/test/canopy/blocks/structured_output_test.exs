defmodule Canopy.Blocks.StructuredOutputTest do
  @moduledoc "Unit + integration tests for the StructuredOutput parser and materializer."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Blocks.StructuredOutput
  alias Canopy.Drive
  alias Canopy.Tasks

  # ---------------------------------------------------------------------------
  # parse/1 — TASK markers
  # ---------------------------------------------------------------------------

  describe "parse/1 — TASK markers" do
    test "extracts a single TASK marker" do
      content = "[TASK:Write tests]Add ExUnit coverage for the parser.[/TASK]"

      assert [{:task, %{title: "Write tests", description: desc}}] =
               StructuredOutput.parse(content)

      assert desc == "Add ExUnit coverage for the parser."
    end

    test "trims whitespace from title and description" do
      content = "[TASK:  Trim me  ]  Description with spaces  [/TASK]"

      assert [{:task, %{title: "Trim me", description: "Description with spaces"}}] =
               StructuredOutput.parse(content)
    end

    test "extracts multiple TASK markers from one block" do
      content = """
      [TASK:First task]Do the first thing.[/TASK]
      Some narrative text in between.
      [TASK:Second task]Do the second thing.[/TASK]
      """

      markers = StructuredOutput.parse(content)
      titles = Enum.map(markers, fn {:task, m} -> m.title end)
      assert titles == ["First task", "Second task"]
    end

    test "handles multiline TASK description" do
      content = "[TASK:Big task]\nLine one.\nLine two.\n[/TASK]"

      assert [{:task, %{title: "Big task", description: desc}}] = StructuredOutput.parse(content)
      assert String.contains?(desc, "Line one.")
      assert String.contains?(desc, "Line two.")
    end
  end

  # ---------------------------------------------------------------------------
  # parse/1 — DRIVE markers
  # ---------------------------------------------------------------------------

  describe "parse/1 — DRIVE markers" do
    test "extracts a DRIVE marker with kind and title" do
      content = "[DRIVE:prompt:My Prompt]Use this prompt for summarization.[/DRIVE]"

      assert [{:drive, %{kind: "prompt", title: "My Prompt", body: body}}] =
               StructuredOutput.parse(content)

      assert body == "Use this prompt for summarization."
    end

    test "extracts a DRIVE marker with kind rule" do
      content = "[DRIVE:rule:Formatting Rule]Always use tabs.[/DRIVE]"

      assert [{:drive, %{kind: "rule", title: "Formatting Rule", body: "Always use tabs."}}] =
               StructuredOutput.parse(content)
    end

    test "extracts multiple DRIVE markers" do
      content = """
      [DRIVE:prompt:Prompt A]Body A.[/DRIVE]
      [DRIVE:rule:Rule B]Body B.[/DRIVE]
      """

      markers = StructuredOutput.parse(content)
      assert length(markers) == 2

      assert Enum.any?(markers, fn {:drive, m} -> m.kind == "prompt" and m.title == "Prompt A" end)

      assert Enum.any?(markers, fn {:drive, m} -> m.kind == "rule" and m.title == "Rule B" end)
    end
  end

  # ---------------------------------------------------------------------------
  # parse/1 — FILE markers
  # ---------------------------------------------------------------------------

  describe "parse/1 — FILE markers" do
    test "extracts a FILE marker" do
      content = "[FILE:src/hello.ex]defmodule Hello do\nend\n[/FILE]"

      assert [{:file, %{path: "src/hello.ex", contents: contents}}] =
               StructuredOutput.parse(content)

      assert String.contains?(contents, "defmodule Hello")
    end

    test "preserves file contents without trimming interior whitespace" do
      file_body = "  indented line\n  another line\n"
      content = "[FILE:app.txt]#{file_body}[/FILE]"

      assert [{:file, %{contents: ^file_body}}] = StructuredOutput.parse(content)
    end
  end

  # ---------------------------------------------------------------------------
  # parse/1 — NOTE markers
  # ---------------------------------------------------------------------------

  describe "parse/1 — NOTE markers" do
    test "extracts a NOTE marker" do
      content = "[NOTE:Quick idea]Ship the feature by Friday.[/NOTE]"

      assert [{:note, %{title: "Quick idea", body: "Ship the feature by Friday."}}] =
               StructuredOutput.parse(content)
    end

    test "extracts NOTE with multiline body" do
      content = "[NOTE:Sprint notes]\n- Item one\n- Item two\n[/NOTE]"

      assert [{:note, %{title: "Sprint notes", body: body}}] = StructuredOutput.parse(content)
      assert String.contains?(body, "Item one")
    end
  end

  # ---------------------------------------------------------------------------
  # parse/1 — Code fence exclusion
  # ---------------------------------------------------------------------------

  describe "parse/1 — code fence exclusion" do
    test "ignores markers inside triple backtick code fences" do
      content = """
      Here is the syntax:

      ```
      [TASK:Example task]This is only documentation.[/TASK]
      [DRIVE:prompt:Example]Docs only.[/DRIVE]
      ```

      No real markers above.
      """

      assert StructuredOutput.parse(content) == []
    end

    test "still extracts markers outside code fences when fences also present" do
      content = """
      ```
      [TASK:Fake]Not real.[/TASK]
      ```

      [TASK:Real task]This one is real.[/TASK]
      """

      assert [{:task, %{title: "Real task"}}] = StructuredOutput.parse(content)
    end
  end

  # ---------------------------------------------------------------------------
  # parse/1 — Edge cases
  # ---------------------------------------------------------------------------

  describe "parse/1 — edge cases" do
    test "returns empty list when content has no markers" do
      assert StructuredOutput.parse("Just a regular agent message with no markers.") == []
    end

    test "returns empty list for empty string" do
      assert StructuredOutput.parse("") == []
    end

    test "returns empty list for nil gracefully" do
      assert StructuredOutput.parse(nil) == []
    end

    test "extracts mixed marker types from one message" do
      content = """
      [TASK:Create a module]Build the GenServer.[/TASK]
      [NOTE:Reminder]Don't forget tests.[/NOTE]
      [DRIVE:rule:No todos]Remove all TODO comments.[/DRIVE]
      """

      markers = StructuredOutput.parse(content)
      assert length(markers) == 3
      types = Enum.map(markers, &elem(&1, 0))
      assert :task in types
      assert :note in types
      assert :drive in types
    end
  end

  # ---------------------------------------------------------------------------
  # materialize/2 — Task creation
  # ---------------------------------------------------------------------------

  describe "materialize/2 — task creation" do
    test "creates a task in the DB from a :task marker" do
      markers = [{:task, %{title: "Agent task", description: "Do something important"}}]
      opts = [workspace_slug: "test-workspace"]

      {:ok, [artifact]} = StructuredOutput.materialize(markers, opts)

      assert artifact.type == :task
      assert artifact.title == "Agent task"
      assert is_binary(artifact.id)

      {:ok, task} = Tasks.get(artifact[:short_id] || find_task_short_id(artifact.id))
      assert task.title == "Agent task"
      assert task.status == "todo"
    end

    test "attaches workspace_slug and session_id to created task" do
      session = insert(:session)
      markers = [{:task, %{title: "Scoped task", description: "With scope"}}]
      opts = [workspace_slug: "my-workspace", session_id: session.id]

      {:ok, [artifact]} = StructuredOutput.materialize(markers, opts)

      task = Canopy.Repo.get(Canopy.Tasks.Task, artifact.id)
      assert task.workspace_slug == "my-workspace"
      assert task.session_id == session.id
    end
  end

  # ---------------------------------------------------------------------------
  # materialize/2 — Drive entry creation
  # ---------------------------------------------------------------------------

  describe "materialize/2 — drive entry creation" do
    test "creates a drive entry from a :drive marker" do
      markers = [
        {:drive, %{kind: "prompt", title: "Summarize text", body: "Given a block of text..."}}
      ]

      {:ok, [artifact]} = StructuredOutput.materialize(markers, [])

      assert artifact.type == :drive
      assert artifact.title == "Summarize text"
      assert artifact.kind == "prompt"
      assert is_binary(artifact.id)

      entry = Drive.get(artifact.id)
      assert entry.name == "Summarize text"
      assert entry.kind == "prompt"
      assert entry.body["body"] == "Given a block of text..."
    end

    test "creates a rule-kind drive entry" do
      markers = [
        {:drive, %{kind: "rule", title: "No dead code", body: "Remove unused functions."}}
      ]

      {:ok, [artifact]} = StructuredOutput.materialize(markers, [])

      assert artifact.type == :drive
      assert artifact.kind == "rule"

      entry = Drive.get(artifact.id)
      assert entry.kind == "rule"
    end
  end

  # ---------------------------------------------------------------------------
  # materialize/2 — Note creation
  # ---------------------------------------------------------------------------

  describe "materialize/2 — note creation" do
    test "creates a drive prompt entry from a :note marker" do
      markers = [{:note, %{title: "Quick note", body: "Remember this."}}]

      {:ok, [artifact]} = StructuredOutput.materialize(markers, [])

      assert artifact.type == :note
      assert artifact.title == "Quick note"
      assert is_binary(artifact.id)

      entry = Drive.get(artifact.id)
      assert entry.kind == "prompt"
      assert entry.body["body"] == "Remember this."
    end
  end

  # ---------------------------------------------------------------------------
  # materialize/2 — Partial failure handling
  # ---------------------------------------------------------------------------

  describe "materialize/2 — partial failure handling" do
    test "returns error artifact without raising when task creation fails" do
      # Pass an invalid marker with a nil title to force a changeset error
      markers = [{:task, %{title: nil, description: "Bad task"}}]

      {:ok, [artifact]} = StructuredOutput.materialize(markers, [])

      assert artifact.type == :error
      assert artifact.marker == :task
    end

    test "creates successful artifacts even when one marker fails" do
      markers = [
        {:task, %{title: nil, description: "Will fail"}},
        {:note, %{title: "Will succeed", body: "Good note"}}
      ]

      {:ok, artifacts} = StructuredOutput.materialize(markers, [])
      assert length(artifacts) == 2

      types = Enum.map(artifacts, & &1.type)
      assert :error in types
      assert :note in types
    end

    test "returns {:ok, []} for an empty markers list" do
      assert {:ok, []} = StructuredOutput.materialize([], [])
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Looks up a task by its UUID id (the factory does not expose short_id directly
  # so we query by primary key here).
  defp find_task_short_id(id) do
    case Canopy.Repo.get(Canopy.Tasks.Task, id) do
      nil -> nil
      task -> task.short_id
    end
  end
end
