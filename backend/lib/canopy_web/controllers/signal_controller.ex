defmodule CanopyWeb.SignalController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{ActivityEvent, Agent}
  import Ecto.Query

  # Signal Theory: S = (M, G, T, F, W)
  # M = Mode (Linguistic, Visual, Code)
  # G = Genre (Spec, Report, PR, ADR, Brief, etc.)
  # T = Type (Direct, Inform, Commit, Decide, Express)
  # F = Format (Markdown, code file, CLI output, diff)
  # W = Structure (genre-specific template/skeleton)

  def classify(conn, params) do
    message = params["message"] || ""

    classification = classify_signal(message)
    json(conn, %{classification: classification, message: message})
  end

  def feed(conn, params) do
    workspace_id = params["workspace_id"]
    limit = min(parse_int(params["limit"], 20), 100)

    query =
      from e in ActivityEvent,
        left_join: a in Agent,
        on: a.id == e.agent_id,
        where: e.level in ["warn", "error"],
        order_by: [desc: e.inserted_at],
        limit: ^limit,
        select: {e, a.name}

    query = if workspace_id, do: where(query, [e], e.workspace_id == ^workspace_id), else: query

    rows = Repo.all(query)

    signals =
      Enum.map(rows, fn {e, agent_name} ->
        channel =
          case String.split(e.event_type || "", ".") do
            [prefix | _] -> prefix
            _ -> "system"
          end

        mode =
          cond do
            String.starts_with?(e.event_type || "", "agent.") -> "EXECUTE"
            String.starts_with?(e.event_type || "", "budget.") -> "ANALYZE"
            true -> "MAINTAIN"
          end

        weight =
          case e.level do
            "error" -> 0.9
            "warn" -> 0.6
            _ -> 0.3
          end

        failure_mode = if e.level == "error", do: "Fidelity Failure", else: nil

        %{
          id: e.id,
          session_id: nil,
          channel: channel,
          mode: mode,
          genre: "INFORM",
          tier: "sonnet",
          weight: weight,
          agent_name: agent_name,
          input_preview: e.message |> to_string() |> String.slice(0, 200),
          failure_mode: failure_mode,
          created_at: e.inserted_at,
          # legacy fields kept for compatibility
          type: e.event_type,
          event_type: e.event_type,
          message: e.message,
          level: e.level,
          workspace_id: e.workspace_id,
          agent_id: e.agent_id,
          inserted_at: e.inserted_at,
          signal_type: level_to_signal_type(e.level)
        }
      end)

    json(conn, %{signals: signals})
  end

  def patterns(conn, params) do
    workspace_id = params["workspace_id"]
    limit = min(parse_int(params["limit"], 10), 50)
    since = DateTime.add(DateTime.utc_now(), -7, :day)

    base_query =
      from e in ActivityEvent,
        where: e.inserted_at >= ^since

    base_query =
      if workspace_id,
        do: where(base_query, [e], e.workspace_id == ^workspace_id),
        else: base_query

    # Frequency analysis: count occurrences of each event_type in the window
    type_counts =
      Repo.all(
        base_query
        |> group_by([e], e.event_type)
        |> select([e], %{event_type: e.event_type, count: count(e.id)})
        |> order_by([e], desc: count(e.id))
        |> limit(^limit)
      )

    total_events = Enum.sum(Enum.map(type_counts, & &1.count))

    patterns =
      type_counts
      |> Enum.with_index(1)
      |> Enum.map(fn {%{event_type: event_type, count: count}, rank} ->
        frequency =
          if total_events > 0,
            do: Float.round(count / total_events * 100, 1),
            else: 0.0

        %{
          rank: rank,
          event_type: event_type,
          count: count,
          frequency_pct: frequency,
          window_days: 7
        }
      end)

    json(conn, %{
      patterns: patterns,
      total_events: total_events,
      window_days: 7
    })
  end

  def stats(conn, params) do
    workspace_id = params["workspace_id"]

    base_query = from(e in ActivityEvent)

    base_query =
      if workspace_id,
        do: where(base_query, [e], e.workspace_id == ^workspace_id),
        else: base_query

    total = Repo.aggregate(base_query, :count)

    level_counts =
      Repo.all(
        base_query
        |> group_by([e], e.level)
        |> select([e], %{level: e.level, count: count(e.id)})
      )

    type_counts =
      Repo.all(
        base_query
        |> group_by([e], e.event_type)
        |> select([e], %{event_type: e.event_type, count: count(e.id)})
        |> order_by([e], desc: count(e.id))
        |> limit(10)
      )

    json(conn, %{
      stats: %{
        total: total,
        by_level: level_counts,
        top_event_types: type_counts
      }
    })
  end

  # --- Private helpers ---

  defp classify_signal(message) do
    mode = infer_mode(message)
    genre = infer_genre(message)
    type = infer_type(message)
    format = infer_format(message)
    structure = infer_structure(genre)

    %{
      mode: mode,
      genre: genre,
      type: type,
      format: format,
      structure: structure,
      noise_indicators: detect_noise(message),
      signal_strength: score_signal(message)
    }
  end

  defp infer_mode(message) do
    cond do
      message =~ ~r/```|def |defmodule |function |class |import / -> "Code"
      message =~ ~r/\|.*\||\[.*\].*:/ -> "Visual"
      true -> "Linguistic"
    end
  end

  defp infer_genre(message) do
    cond do
      message =~ ~r/\bfix\b|\bbug\b|\berror\b/i -> "BugReport"
      message =~ ~r/\bspec\b|\brequirement\b|\bmust\b|\bshall\b/i -> "Spec"
      message =~ ~r/\bdecision\b|\barchitecture\b|\badr\b/i -> "ADR"
      message =~ ~r/\bsummary\b|\bbrief\b|\bTL;?DR\b/i -> "Brief"
      message =~ ~r/\breport\b|\bmetrics\b|\bstatus\b/i -> "Report"
      message =~ ~r/\btask\b|\btodo\b|\baction\b/i -> "ActionItem"
      true -> "General"
    end
  end

  defp infer_type(message) do
    cond do
      message =~ ~r/^(do|run|create|update|delete|fix|build|deploy)\b/i -> "Direct"
      message =~ ~r/\bdecided\b|\bwill\b|\bcommitting\b/i -> "Commit"
      message =~ ~r/\bshould\b|\bconsider\b|\bpropose\b/i -> "Decide"
      message =~ ~r/\bFYI\b|\bnote\b|\baware\b/i -> "Inform"
      true -> "Inform"
    end
  end

  defp infer_format(message) do
    cond do
      message =~ ~r/^```/ -> "CodeBlock"
      message =~ ~r/^#+ / -> "Markdown"
      message =~ ~r/^\s*[-*]\s/ -> "BulletList"
      message =~ ~r/\|.*\|/ -> "Table"
      true -> "PlainText"
    end
  end

  defp infer_structure(genre) do
    case genre do
      "Spec" -> ["Overview", "Requirements", "Acceptance Criteria", "Out of Scope"]
      "BugReport" -> ["Summary", "Steps to Reproduce", "Expected", "Actual", "Fix"]
      "ADR" -> ["Context", "Decision", "Consequences", "Alternatives"]
      "Brief" -> ["Summary", "Key Points", "Action Items"]
      "Report" -> ["Summary", "Metrics", "Findings", "Next Steps"]
      "ActionItem" -> ["What", "Who", "By When", "Definition of Done"]
      _ -> ["Content"]
    end
  end

  defp detect_noise(message) do
    indicators = []

    indicators =
      if message =~ ~r/\bI think\b|\bmaybe\b|\bperhaps\b/i,
        do: ["hedging" | indicators],
        else: indicators

    indicators =
      if message =~ ~r/\bthat's a great\b|\bthank you for\b/i,
        do: ["filler" | indicators],
        else: indicators

    indicators =
      if String.length(message) > 2000, do: ["bandwidth_overload" | indicators], else: indicators

    indicators
  end

  defp score_signal(message) do
    word_count = message |> String.split() |> length()
    has_structure = message =~ ~r/^#|\n- |\n\*/m
    has_action = message =~ ~r/\b(do|create|fix|update|run|deploy|review)\b/i

    base = 5
    base = if word_count in 10..200, do: base + 2, else: base
    base = if has_structure, do: base + 2, else: base
    base = if has_action, do: base + 1, else: base
    min(base, 10)
  end

  defp level_to_signal_type("error"), do: "critical"
  defp level_to_signal_type("warn"), do: "warning"
  defp level_to_signal_type(_), do: "info"
end
