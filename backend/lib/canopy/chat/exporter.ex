defmodule Canopy.Chat.Exporter do
  @moduledoc """
  Converts a thread's concatenated SessionMessage list to GitHub-Flavored Markdown.

  Supported message kinds and their rendering:
    - `user`        → `### You\\n\\n{content}\\n\\n`
    - `assistant`   → `### Assistant\\n\\n{content}\\n\\n`
    - `tool_call`   → `> Tool: {name}({args_preview})`
    - `tool_result` → `<details><summary>Tool result</summary>{content}</details>` (GFM)
    - `thinking`    → skipped by default; opts `include_thinking: true` to render
    - `diff`        → fenced ```diff code block
    - `system`      → `> ⚠ System: {message}`
    - `stderr`      → `> ⚠ Error: {message}`
    - `stdout`      → omitted (noise)
    - `init`        → omitted
    - `result`      → omitted

  The document opens with a header block: title, agent, timestamp, session count.
  """

  alias Canopy.Chat.Thread
  alias Canopy.Sessions.SessionMessage

  @doc """
  Generates a markdown string from a thread and its ordered messages.

  Options:
    - `:include_thinking` — when `true`, renders `:thinking` blocks (default false)
  """
  @spec export(Thread.t(), [SessionMessage.t()], keyword()) :: String.t()
  def export(%Thread{} = thread, messages, opts \\ []) do
    include_thinking = Keyword.get(opts, :include_thinking, false)

    header = render_header(thread, messages)
    body = Enum.map_join(messages, "", &render_message(&1, include_thinking))

    header <> body
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec render_header(Thread.t(), [SessionMessage.t()]) :: String.t()
  defp render_header(thread, messages) do
    title = thread.title || "Untitled Thread"
    agent = thread.agent_slug || "—"
    timestamp = format_datetime(thread.inserted_at)
    session_count = count_sessions(messages)

    """
    # #{title}

    **Agent:** #{agent}
    **Started:** #{timestamp}
    **Sessions:** #{session_count}

    ---

    """
  end

  @spec render_message(SessionMessage.t(), boolean()) :: String.t()
  defp render_message(%SessionMessage{kind: "user"} = msg, _include_thinking) do
    text = extract_text(msg.content)
    "### You\n\n#{text}\n\n"
  end

  defp render_message(%SessionMessage{kind: "assistant"} = msg, _include_thinking) do
    text = extract_text(msg.content)
    "### Assistant\n\n#{text}\n\n"
  end

  defp render_message(%SessionMessage{kind: "tool_call"} = msg, _include_thinking) do
    name = get_in(msg.content, ["tool"]) || get_in(msg.content, ["name"]) || "unknown"
    args = msg.content["args"] || msg.content["input"] || %{}
    args_preview = format_args_preview(args)
    "> Tool: #{name}(#{args_preview})\n\n"
  end

  defp render_message(%SessionMessage{kind: "tool_result"} = msg, _include_thinking) do
    content = extract_text(msg.content)

    "<details><summary>Tool result</summary>\n\n#{content}\n\n</details>\n\n"
  end

  defp render_message(%SessionMessage{kind: "thinking"} = msg, true) do
    text = extract_text(msg.content)
    "<details><summary>Thinking</summary>\n\n#{text}\n\n</details>\n\n"
  end

  defp render_message(%SessionMessage{kind: "thinking"}, false), do: ""

  defp render_message(%SessionMessage{kind: "diff"} = msg, _include_thinking) do
    patch = extract_text(msg.content)
    "```diff\n#{patch}\n```\n\n"
  end

  defp render_message(%SessionMessage{kind: "system"} = msg, _include_thinking) do
    text = extract_text(msg.content)
    "> ⚠ System: #{text}\n\n"
  end

  defp render_message(%SessionMessage{kind: "stderr"} = msg, _include_thinking) do
    text = extract_text(msg.content)
    "> ⚠ Error: #{text}\n\n"
  end

  # stdout, init, result, and any unknown kinds are omitted
  defp render_message(%SessionMessage{}, _include_thinking), do: ""

  # Extracts displayable text from a content map. The content schema varies by kind
  # but consistently uses "text" or "output" as the primary key.
  @spec extract_text(map() | nil) :: String.t()
  defp extract_text(nil), do: ""

  defp extract_text(content) when is_map(content) do
    content["text"] || content["output"] || content["message"] || content["content"] ||
      Jason.encode!(content)
  end

  defp extract_text(content) when is_binary(content), do: content
  defp extract_text(_), do: ""

  # Formats tool args as a compact one-line preview (max 80 chars)
  @spec format_args_preview(map() | list() | term()) :: String.t()
  defp format_args_preview(args) when is_map(args) do
    encoded = Jason.encode!(args)

    if String.length(encoded) > 80 do
      String.slice(encoded, 0, 77) <> "..."
    else
      encoded
    end
  end

  defp format_args_preview(args) when is_list(args), do: Enum.join(args, ", ")
  defp format_args_preview(args), do: inspect(args)

  # Counts the number of distinct session_ids to report session count in header
  @spec count_sessions([SessionMessage.t()]) :: non_neg_integer()
  defp count_sessions(messages) do
    messages
    |> Enum.map(& &1.session_id)
    |> Enum.uniq()
    |> length()
  end

  @spec format_datetime(DateTime.t() | NaiveDateTime.t() | nil) :: String.t()
  defp format_datetime(nil), do: "—"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  end

  defp format_datetime(%NaiveDateTime{} = ndt) do
    Calendar.strftime(ndt, "%Y-%m-%d %H:%M UTC")
  end
end
