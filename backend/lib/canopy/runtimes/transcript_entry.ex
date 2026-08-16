defmodule Canopy.Runtimes.TranscriptEntry do
  @moduledoc """
  Wire format for a single event in a session transcript.

  Discriminated union representing every event emitted by a runtime
  adapter — assistant text, thinking blocks, tool calls, tool results,
  diffs, stdout/stderr, and system signals — maps to one of the kinds below.

  Notable design points:
  - `sequence` — monotonically increasing counter within a session, assigned by
    the Runner before publishing. Enables gapless ordering in the UI even when
    PubSub events arrive out of order under load.
  - `tool_call_id` — present on `:tool_call` and `:tool_result` pairs so the UI
    can correlate them visually without a separate lookup.
  - `emitted_at` — UTC timestamp in microsecond precision (`DateTime`) so
    downstream code can sort without parsing.

  Persistence: the Runner converts `TranscriptEntry` to a `SessionMessage` before
  writing to the database. The entry itself is never persisted — it is the
  in-flight representation used by PubSub and SSE.
  """

  @enforce_keys [:kind, :content, :emitted_at]
  defstruct [:kind, :content, :emitted_at, :tool_call_id, :sequence]

  @type kind ::
          :assistant
          | :thinking
          | :tool_call
          | :tool_result
          | :diff
          | :stderr
          | :stdout
          | :system
          | :user
          | :init
          | :result

  @type t :: %__MODULE__{
          kind: kind(),
          # Variant-specific payload as a plain map — see Parser for each shape.
          content: map(),
          emitted_at: DateTime.t(),
          # Present on :tool_call and :tool_result for correlation.
          tool_call_id: String.t() | nil,
          # Assigned by Runner; nil until emitted.
          sequence: non_neg_integer() | nil
        }

  @doc """
  Returns an entry stamped with the current UTC time and sequence number.

  Convenience constructor used in tests and the Runner to avoid repeating
  the `%TranscriptEntry{emitted_at: DateTime.utc_now()}` boilerplate.
  """
  @spec new(kind(), map(), keyword()) :: t()
  def new(kind, content, opts \\ []) do
    %__MODULE__{
      kind: kind,
      content: content,
      emitted_at: Keyword.get(opts, :emitted_at, DateTime.utc_now()),
      tool_call_id: Keyword.get(opts, :tool_call_id),
      sequence: Keyword.get(opts, :sequence)
    }
  end
end
