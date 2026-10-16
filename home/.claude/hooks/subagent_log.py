#!/usr/bin/env python3
"""SubagentStop hook: record what each subagent actually returned to the parent.

Appends one JSON line per subagent invocation to ~/.claude/subagent-log.jsonl.

The number that matters is `return_chars`: the size of the final message the
subagent handed back. That message is the only part of the subagent's work that
lands in the parent's context, so it is the whole measure of whether the
context firewall is holding.

Design rules, in priority order:
  1. Never fail the session. Every exception is swallowed; the hook always
     exits 0. A logging hook that breaks Claude Code is worse than no hook.
  2. Never write to stdout. SubagentStop reads stdout as control JSON.
  3. Parse the transcript defensively. Its format is internal and changes
     between Claude Code versions, so failure to parse is expected sometimes
     and must degrade to a zero-length record, not a crash.
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

# Returns larger than this (characters) suggest the agent's output contract is
# leaking — dumping content instead of reporting findings. Tune from real data
# after a week; these are starting guesses.
LEAK_THRESHOLDS = {
    "scout": 2500,
    "diff-reviewer": 6000,
    "sleuth": 5000,
}
DEFAULT_THRESHOLD = 6000


def config_dir() -> Path:
    return Path(os.environ.get("CLAUDE_CONFIG_DIR") or (Path.home() / ".claude"))


def extract_text(block) -> str:
    """Pull display text out of one content block, whatever shape it has."""
    if isinstance(block, str):
        return block
    if isinstance(block, dict):
        if isinstance(block.get("text"), str):
            return block["text"]
        # tool_result blocks nest their payload one level deeper
        inner = block.get("content")
        if isinstance(inner, list):
            return "".join(extract_text(b) for b in inner)
        if isinstance(inner, str):
            return inner
    return ""


def final_message(transcript: Path) -> str:
    """Text of the last assistant message in a transcript.

    Walks backwards and takes the first entry that yields text, so a trailing
    metadata or summary record doesn't defeat it. Returns "" if the file is
    missing or the format has drifted past recognition — a zero here means
    "couldn't read it", not "returned nothing".
    """
    try:
        lines = transcript.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""

    for line in reversed(lines):
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(entry, dict):
            continue

        # The message may sit at the top level or nested under "message".
        nested = entry.get("message")
        message = nested if isinstance(nested, dict) else entry

        # Accept assistant turns, and entries with no role at all (format drift).
        if message.get("role") not in (None, "assistant"):
            continue

        content = message.get("content")
        if isinstance(content, str):
            text = content
        elif isinstance(content, list):
            text = "".join(extract_text(b) for b in content)
        else:
            continue

        if text.strip():
            return text

    return ""


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return
    if not isinstance(payload, dict):
        return

    agent_type = payload.get("agent_type") or "unknown"
    transcript = payload.get("agent_transcript_path")
    text = final_message(Path(transcript)) if transcript else ""

    chars = len(text)
    threshold = LEAK_THRESHOLDS.get(agent_type, DEFAULT_THRESHOLD)

    record = {
        "ts": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "agent": agent_type,
        "agent_id": payload.get("agent_id"),
        "session_id": payload.get("session_id"),
        "cwd": payload.get("cwd"),
        "return_chars": chars,
        "return_tokens_est": chars // 4,  # rough, but fine for watching a trend
        "code_fences": text.count("```"),
        "over_threshold": chars > threshold,
        "threshold": threshold,
        "transcript": transcript,
    }

    try:
        path = config_dir() / "subagent-log.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record) + "\n")
    except OSError:
        pass


if __name__ == "__main__":
    try:
        main()
    except Exception:  # noqa: BLE001 — a logging hook must never break the session
        pass
    sys.exit(0)
