# /report

> Generate structured reports. Director-owned.

## Usage
```
/report <topic> [--format <brief|detailed|executive>] [--period <week|month|quarter>]
```

## What It Does
Compiles data from the knowledge base into a structured report formatted for the
target audience. Director reviews all reports before external delivery.

## Implementation
1. **Gather** — Search for relevant data and signals.
2. **Aggregate** — Group findings by theme or timeline.
3. **Format** — Apply report template matching `--format`.
4. **Deliver** — Output the formatted report.

## Examples
```bash
/report "sprint status" --format brief --period week
/report "Q1 performance" --format executive --period quarter
```
