#!/usr/bin/env python3
"""PreToolUse hook: append quiet flags to known-noisy Bash commands.

Trims token-heavy output at the source (vitest's default reporter, unbounded
git log). Only rewrites a single simple command; anything compound (&&, ||,
;, |, newlines, subshells, backticks, redirections) passes through untouched
so operator and quoting semantics are never disturbed.

Input:  hook JSON on stdin with tool_name and tool_input.command
Output: {"hookSpecificOutput": {"hookEventName": "PreToolUse",
         "updatedInput": {...}}} when a rewrite applies; silent exit 0 otherwise.
"""

import json
import re
import sys

COMPOUND_TOKENS = ("&&", "||", ";", "|", "\n", "$(", "`", ">", "<")

# Matches only actual vitest invocations at the start of the command
# (vitest, yarn/npx/pnpm vitest, node_modules/.bin/vitest), not commands
# that merely mention the word (grep, echo).
VITEST_INVOCATION_RE = re.compile(
    r"^(?:(?:yarn|npx|pnpm)\s+(?:run\s+)?)?(?:\.?/?node_modules/\.bin/)?vitest\b"
)

GIT_LOG_RE = re.compile(r"^git\s+log\b")
GIT_LOG_COUNT_RE = re.compile(r"(^|\s)(-n\s*\d+|-\d+\b|--max-count(=|\s))")

VITEST_SKIP_MARKERS = ("--reporter", "--version", "--help")


def is_simple(command):
    """True when the command has no shell operators outside quotes."""
    in_single = in_double = False
    i = 0
    while i < len(command):
        ch = command[i]
        if ch == "\\" and not in_single:
            i += 2
            continue
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double
        elif not in_single and not in_double:
            for token in COMPOUND_TOKENS:
                if command.startswith(token, i):
                    return False
        i += 1
    return True


def rewrite(command):
    """Return the quieter command, or None when no rewrite applies."""
    if VITEST_INVOCATION_RE.match(command):
        if not any(marker in command for marker in VITEST_SKIP_MARKERS):
            return command + " --reporter=dot"
        return None
    if GIT_LOG_RE.match(command):
        if not GIT_LOG_COUNT_RE.search(command):
            return command + " -n 30"
        return None
    return None


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    if data.get("tool_name") != "Bash":
        sys.exit(0)

    tool_input = data.get("tool_input") or {}
    command = (tool_input.get("command") or "").strip()
    if not command or not is_simple(command):
        sys.exit(0)

    new_command = rewrite(command)
    if not new_command:
        sys.exit(0)

    updated = dict(tool_input)
    updated["command"] = new_command
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "updatedInput": updated,
            }
        },
        sys.stdout,
    )
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
