defmodule Canopy.Routines.Cron do
  @moduledoc """
  Pure Elixir POSIX cron expression parser.

  Supports:
  - Wildcards: `*`
  - Step values: `*/15`, `0-23/2`
  - Lists: `1,3,5`
  - Ranges: `1-5`
  - Named aliases: `@hourly`, `@daily`, `@midnight`, `@weekly`, `@monthly`

  ## Usage

      iex> Canopy.Routines.Cron.next_after("0 9 * * 1", ~U[2026-04-20 08:59:00Z])
      ~U[2026-04-27 09:00:00Z]

      iex> Canopy.Routines.Cron.next_after("*/5 * * * *", ~U[2026-04-20 09:03:00Z])
      ~U[2026-04-20 09:05:00Z]
  """

  @aliases %{
    "@hourly" => "0 * * * *",
    "@daily" => "0 0 * * *",
    "@midnight" => "0 0 * * *",
    "@weekly" => "0 0 * * 0",
    "@monthly" => "0 0 1 * *"
  }

  @doc """
  Returns the next fire DateTime strictly after `from`.

  Raises `ArgumentError` for invalid expressions.
  """
  @spec next_after(String.t(), DateTime.t()) :: DateTime.t()
  def next_after(expression, %DateTime{} = from) do
    expr = Map.get(@aliases, expression, expression)
    {minutes, hours, days, months, weekdays} = parse!(expr)

    # Start searching from the next whole minute after `from`
    start = from |> DateTime.truncate(:second) |> advance_minute()
    find_next(start, minutes, hours, days, months, weekdays, 0)
  end

  @doc """
  Returns a list of the next `count` fire DateTimes after `from`.
  """
  @spec next_n(String.t(), DateTime.t(), pos_integer()) :: [DateTime.t()]
  def next_n(expression, from, count) when count > 0 do
    Enum.reduce(1..count, {from, []}, fn _, {last, acc} ->
      nxt = next_after(expression, last)
      {nxt, [nxt | acc]}
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  # ---------------------------------------------------------------------------
  # Internal search
  # ---------------------------------------------------------------------------

  # Hard cap: search at most 4 years (527,040 minutes) to avoid infinite loop
  # on degenerate expressions like "31 * * 2 *".
  @max_minutes 527_040

  defp find_next(_dt, _min, _hr, _d, _mo, _wd, iter) when iter >= @max_minutes do
    raise ArgumentError, "cron expression never fires in the next 4 years"
  end

  defp find_next(dt, minutes, hours, days, months, weekdays, iter) do
    if matches?(dt, minutes, hours, days, months, weekdays) do
      dt
    else
      find_next(advance_minute(dt), minutes, hours, days, months, weekdays, iter + 1)
    end
  end

  defp matches?(dt, minutes, hours, days, months, weekdays) do
    # day-of-week: cron uses 0=Sunday..6=Saturday; Date.day_of_week returns 1=Mon..7=Sun
    dow =
      case Date.day_of_week(dt) do
        7 -> 0
        n -> n
      end

    # When both day-of-month and day-of-week are restricted, OR them (POSIX behaviour)
    dt.minute in minutes and
      dt.hour in hours and
      dt.month in months and
      (days == :any or dt.day in days) and
      (weekdays == :any or dow in weekdays) and
      (days == :any or weekdays == :any or dt.day in days or dow in weekdays)
  end

  defp advance_minute(%DateTime{} = dt) do
    DateTime.add(dt, 60, :second)
    |> DateTime.truncate(:second)
    |> zero_seconds()
  end

  defp zero_seconds(%DateTime{} = dt), do: %{dt | second: 0}

  # ---------------------------------------------------------------------------
  # Parser
  # ---------------------------------------------------------------------------

  @spec parse!(String.t()) ::
          {[integer()], [integer()], [integer()] | :any, [integer()], [integer()] | :any}
  defp parse!(expr) do
    parts = String.split(expr, " ", trim: true)

    unless length(parts) == 5 do
      raise ArgumentError,
            "invalid cron expression #{inspect(expr)}: expected 5 fields (min hr dom mon dow)"
    end

    [min_s, hr_s, dom_s, mon_s, dow_s] = parts

    minutes = expand(min_s, 0, 59)
    hours = expand(hr_s, 0, 23)
    months = expand(mon_s, 1, 12)

    # For day-of-month and day-of-week, we track :any separately so the
    # OR behaviour (POSIX) is correct when both are restricted.
    days =
      case dom_s do
        "*" -> :any
        _ -> expand(dom_s, 1, 31)
      end

    weekdays =
      case dow_s do
        "*" -> :any
        _ -> expand(dow_s, 0, 6)
      end

    {minutes, hours, days, months, weekdays}
  end

  # Expand a single cron field into a sorted list of integers.
  @spec expand(String.t(), integer(), integer()) :: [integer()]
  defp expand(field, min, max) do
    field
    |> String.split(",", trim: true)
    |> Enum.flat_map(&expand_segment(&1, min, max))
    |> Enum.uniq()
    |> Enum.sort()
  end

  # */step  →  min..max//step
  defp expand_segment("*/" <> step_s, min, max) do
    step = parse_int!(step_s)
    Enum.take_every(min..max, step)
  end

  # range/step  →  range//step
  defp expand_segment(seg, _min, max) when is_binary(seg) do
    case String.split(seg, "/", parts: 2) do
      [range_s, step_s] ->
        step = parse_int!(step_s)
        {lo, hi} = parse_range(range_s, max)
        Enum.take_every(lo..hi, step)

      [_] ->
        case String.split(seg, "-", parts: 2) do
          [lo_s, hi_s] ->
            lo = parse_int!(lo_s)
            hi = parse_int!(hi_s)
            Enum.to_list(lo..hi)

          [val_s] ->
            [parse_int!(val_s)]
        end
    end
  end

  defp parse_range(range_s, max) do
    case String.split(range_s, "-", parts: 2) do
      [lo_s, hi_s] -> {parse_int!(lo_s), parse_int!(hi_s)}
      ["*"] -> {0, max}
      [lo_s] -> {parse_int!(lo_s), max}
    end
  end

  defp parse_int!(s) do
    case Integer.parse(s) do
      {n, ""} -> n
      _ -> raise ArgumentError, "invalid cron integer: #{inspect(s)}"
    end
  end
end
