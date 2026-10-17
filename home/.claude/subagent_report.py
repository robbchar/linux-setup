#!/usr/bin/env python3
"""Summarize the subagent log — is the context firewall holding?

Reads ~/.claude/subagent-log.jsonl (written by subagent_log.py) and reports,
per agent, how much each invocation handed back to the parent context.

Usage:
    python subagent_report.py          # all time
    python subagent_report.py 7        # last 7 days
    python subagent_report.py 7 --worst  # also list the biggest returns
"""

from __future__ import annotations

import json
import os
import statistics
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path


def log_path() -> Path:
    base = os.environ.get("CLAUDE_CONFIG_DIR") or (Path.home() / ".claude")
    return Path(base) / "subagent-log.jsonl"


def load(days: int | None):
    path = log_path()
    if not path.exists():
        sys.exit(f"no log yet at {path} — has the hook fired?")

    cutoff = None
    if days is not None:
        cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if cutoff is not None:
            try:
                if datetime.fromisoformat(rec["ts"]) < cutoff:
                    continue
            except (KeyError, ValueError):
                continue
        yield rec


def percentile(sorted_values: list[int], fraction: float) -> int:
    if not sorted_values:
        return 0
    index = min(len(sorted_values) - 1, int(len(sorted_values) * fraction))
    return sorted_values[index]


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    show_worst = "--worst" in sys.argv
    days = int(args[0]) if args else None

    records = list(load(days))
    if not records:
        sys.exit("no records in range")

    by_agent: dict[str, list[dict]] = defaultdict(list)
    for rec in records:
        by_agent[rec.get("agent", "unknown")].append(rec)

    window = f"last {days}d" if days else "all time"
    print(f"\nSubagent returns to parent context ({window})\n")
    header = f"{'agent':<16}{'calls':>6}{'median':>9}{'p90':>9}{'worst':>9}{'over':>7}{'fenced':>8}"
    print(header)
    print("-" * len(header))

    for agent in sorted(by_agent, key=lambda a: -len(by_agent[a])):
        recs = by_agent[agent]
        sizes = sorted(r.get("return_chars", 0) for r in recs)
        over = sum(1 for r in recs if r.get("over_threshold"))
        fenced = sum(1 for r in recs if r.get("code_fences", 0) >= 2)
        print(
            f"{agent:<16}{len(recs):>6}{int(statistics.median(sizes)):>9}"
            f"{percentile(sizes, 0.9):>9}{sizes[-1]:>9}{over:>7}{fenced:>8}"
        )

    total_chars = sum(r.get("return_chars", 0) for r in records)
    print(
        f"\n{len(records)} invocations, ~{total_chars // 4:,} tokens total "
        f"returned into parent contexts."
    )

    if show_worst:
        print("\nBiggest returns:\n")
        worst = sorted(records, key=lambda r: -r.get("return_chars", 0))[:10]
        for rec in worst:
            flag = "LEAK" if rec.get("over_threshold") else "    "
            print(
                f"  {flag}  {rec.get('ts', '?'):<22}{rec.get('agent', '?'):<16}"
                f"{rec.get('return_chars', 0):>8} chars   {rec.get('cwd', '')}"
            )

    print(
        "\nSizes are characters handed back to the parent. 'over' exceeded the agent's\n"
        "threshold; 'fenced' returned code blocks. Either means the agent's output\n"
        "contract needs tightening — not that the agent fired when it shouldn't have.\n"
    )


if __name__ == "__main__":
    main()
