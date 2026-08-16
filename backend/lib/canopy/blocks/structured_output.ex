defmodule Canopy.Blocks.StructuredOutput do
  @moduledoc """
  Parses agent output for structured markers and materializes artifacts.

  Agents embed markers in their message content to signal intent. This module
  extracts those markers and creates real DB records or workspace files.

  ## Marker syntax

  - `[TASK:title]description[/TASK]`            → creates a Task (status: todo)
  - `[DRIVE:kind:title]body[/DRIVE]`            → creates a Drive entry (kind = workflow/prompt/notebook/rule)
  - `[FILE:path]contents[/FILE]`                → writes a file to the workspace filesystem
  - `[NOTE:title]body[/NOTE]`                   → creates a Drive entry with kind "prompt" (quick note)

  Markers inside triple-backtick code fences are ignored so agents can
  document syntax without triggering materialization.

  ## Integration point

  After inserting a block with `kind: "agent_message"`, callers should invoke:

      content = block.output_text || block.input_text || ""
      case Canopy.Blocks.StructuredOutput.parse(content) do
        [] -> :noop
        markers ->
          Canopy.Blocks.StructuredOutput.materialize(markers,
            workspace_slug: session.workspace_slug,
            session_id: session.id,
            agent_slug: session.agent_slug
          )
      end

  See `Canopy.Blocks.PostProcessor` for the ready-made wrapper that applies
  this automatically when creating agent_message blocks.
  """

  require Logger

  alias Canopy.Drive
  alias Canopy.Tasks
  alias Canopy.Workspaces

  @type marker ::
          {:task, %{title: String.t(), description: String.t()}}
          | {:drive, %{kind: String.t(), title: String.t(), body: String.t()}}
          | {:file, %{path: String.t(), contents: String.t()}}
          | {:note, %{title: String.t(), body: String.t()}}

  @type artifact ::
          %{type: :task, id: String.t(), title: String.t()}
          | %{type: :drive, id: String.t(), title: String.t(), kind: String.t()}
          | %{type: :file, path: String.t()}
          | %{type: :note, id: String.t(), title: String.t()}
          | %{type: :error, marker: atom(), reason: term()}

  # ---------------------------------------------------------------------------
  # Parse
  # ---------------------------------------------------------------------------

  @doc """
  Extracts all structured markers from agent message content.

  Strips triple-backtick code fences before scanning so markers inside
  code examples are not processed.

  Returns a (possibly empty) list of marker tuples.
  """
  @spec parse(String.t()) :: [marker()]
  def parse(content) when is_binary(content) do
    stripped = strip_code_fences(content)

    []
    |> extract_tasks(stripped)
    |> extract_drives(stripped)
    |> extract_files(stripped)
    |> extract_notes(stripped)
  end

  def parse(_), do: []

  # ---------------------------------------------------------------------------
  # Materialize
  # ---------------------------------------------------------------------------

  @doc """
  Materializes parsed markers into actual DB records or workspace files.

  Options:
  - `:workspace_slug` — required for task creation and file writes
  - `:session_id` — optional; attached to created tasks
  - `:agent_slug` — optional; informational

  Returns `{:ok, [artifact]}` where each artifact is a map describing what
  was created. On partial failure the successfully created artifacts are still
  returned alongside error entries so callers get maximum value from a single
  agent message.
  """
  @spec materialize([marker()], keyword()) :: {:ok, [artifact()]}
  def materialize(markers, opts) when is_list(markers) do
    results = Enum.map(markers, &do_materialize(&1, opts))
    {:ok, results}
  end

  # ---------------------------------------------------------------------------
  # Private — parsing
  # ---------------------------------------------------------------------------

  # Remove content inside triple-backtick fences before marker extraction.
  # This prevents markers in code examples from being materialized.
  defp strip_code_fences(content) do
    Regex.replace(~r/```.*?```/s, content, "")
  end

  defp extract_tasks(acc, content) do
    pattern = ~r/\[TASK:(.*?)\](.*?)\[\/TASK\]/s

    tasks =
      Regex.scan(pattern, content, capture: :all_but_first)
      |> Enum.map(fn [title, description] ->
        {:task, %{title: String.trim(title), description: String.trim(description)}}
      end)

    acc ++ tasks
  end

  defp extract_drives(acc, content) do
    pattern = ~r/\[DRIVE:(\w+):(.*?)\](.*?)\[\/DRIVE\]/s

    drives =
      Regex.scan(pattern, content, capture: :all_but_first)
      |> Enum.map(fn [kind, title, body] ->
        {:drive, %{kind: String.trim(kind), title: String.trim(title), body: String.trim(body)}}
      end)

    acc ++ drives
  end

  defp extract_files(acc, content) do
    pattern = ~r/\[FILE:(.*?)\](.*?)\[\/FILE\]/s

    files =
      Regex.scan(pattern, content, capture: :all_but_first)
      |> Enum.map(fn [path, contents] ->
        {:file, %{path: String.trim(path), contents: contents}}
      end)

    acc ++ files
  end

  defp extract_notes(acc, content) do
    pattern = ~r/\[NOTE:(.*?)\](.*?)\[\/NOTE\]/s

    notes =
      Regex.scan(pattern, content, capture: :all_but_first)
      |> Enum.map(fn [title, body] ->
        {:note, %{title: String.trim(title), body: String.trim(body)}}
      end)

    acc ++ notes
  end

  # ---------------------------------------------------------------------------
  # Private — materialization
  # ---------------------------------------------------------------------------

  defp do_materialize({:task, %{title: title, description: description}}, opts) do
    attrs = %{
      title: title,
      description: description,
      workspace_slug: opts[:workspace_slug],
      session_id: opts[:session_id],
      status: "todo"
    }

    case Tasks.create(attrs) do
      {:ok, task} ->
        %{type: :task, id: task.id, title: task.title}

      {:error, reason} ->
        Logger.warning(
          "[StructuredOutput] failed to create task #{inspect(title)}: #{inspect(reason)}"
        )

        %{type: :error, marker: :task, reason: reason}
    end
  end

  defp do_materialize({:drive, %{kind: kind, title: title, body: body}}, _opts) do
    slug = slugify(title)

    attrs = %{
      "kind" => kind,
      "name" => title,
      "slug" => slug,
      "scope" => "personal",
      "body" => %{"body" => body}
    }

    case Drive.create(attrs) do
      {:ok, entry} ->
        %{type: :drive, id: entry.id, title: entry.name, kind: entry.kind}

      {:error, reason} ->
        Logger.warning(
          "[StructuredOutput] failed to create drive entry #{inspect(title)}: #{inspect(reason)}"
        )

        %{type: :error, marker: :drive, reason: reason}
    end
  end

  defp do_materialize({:file, %{path: path, contents: contents}}, opts) do
    workspace_slug = opts[:workspace_slug]

    result =
      with {:slug, slug} when is_binary(slug) <- {:slug, workspace_slug},
           {:ws, {:ok, workspace}} <- {:ws, Workspaces.get_by_slug(slug)} do
        Canopy.Workspaces.Files.write_file(workspace, path, contents)
      else
        {:slug, nil} ->
          {:error, :no_workspace_slug}

        {:ws, {:error, reason}} ->
          {:error, reason}
      end

    case result do
      :ok ->
        %{type: :file, path: path}

      {:error, reason} ->
        Logger.warning(
          "[StructuredOutput] failed to write file #{inspect(path)}: #{inspect(reason)}"
        )

        %{type: :error, marker: :file, reason: reason}
    end
  end

  defp do_materialize({:note, %{title: title, body: body}}, opts) do
    # Notes materialize as prompt-kind Drive entries.
    do_materialize({:drive, %{kind: "prompt", title: title, body: body}}, opts)
    |> case do
      %{type: :drive} = artifact -> Map.put(artifact, :type, :note)
      error -> error
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Produces a lowercase alphanumeric slug from a title.
  # Appends a short random suffix to avoid slug collisions in Drive.
  defp slugify(title) do
    base =
      title
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")
      |> String.slice(0, 80)

    suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    "#{base}-#{suffix}"
  end
end
