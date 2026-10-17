#!/usr/bin/env python3
"""PreToolUse hook that auto-approves read-only Bash commands.

Solves two problems:
1. `git -C /path <subcmd>` doesn't match `Bash(git <subcmd>:*)` patterns
2. `cd /path && git <subcmd>` compound commands don't match either

The hook normalises these forms and checks against a read-only allowlist.
If the command is safe, it returns permissionDecision: "allow" to bypass
the permission prompt entirely. Otherwise it falls through to the normal
permission system (exit 0, no JSON).
"""

import json
import re
import sys

# Read-only git subcommands (these never mutate the repo)
_SAFE_GIT_SUBCOMMANDS = frozenset({
    "blame",
    "branch",
    "config",
    "describe",
    "diff",
    "log",
    "ls-files",
    "ls-tree",
    "reflog",
    "remote",
    "rev-parse",
    "shortlog",
    "show",
    "stash list",
    "status",
    "tag",
})

# Read-only general commands (prefix match)
_SAFE_COMMAND_PREFIXES = [
    "cat ",
    "column ",
    "comm ",
    "cmp ",
    "cut ",
    "date",
    "df ",
    "diff ",
    "du ",
    "expr ",
    "fd ",
    "file ",
    "find ",
    "getconf ",
    "head ",
    "id",
    "jq ",
    "less ",
    "ls",
    "numfmt ",
    "od ",
    "paste ",
    "pr ",
    "printf ",
    "pwd",
    "readlink ",
    "realpath ",
    "seq ",
    "sort ",
    "stat ",
    "tail ",
    "tee ",
    "test ",
    "tr ",
    "tree",
    "tsort ",
    "type ",
    "uname",
    "uniq ",
    "wc ",
    "which ",
    "whoami",
    "xargs ",
]

# Commands that check versions / help (exact prefix)
_SAFE_INFO_PREFIXES = [
    "python3 --version",
    "python --version",
    "node --version",
    "npm --version",
    "uv --version",
    "just --version",
    "just --list",
    "just list",
]


def _normalise_git_command(cmd: str) -> str | None:
    """Extract the git subcommand, stripping -C /path if present."""
    match = re.match(
        r"^git\s+"
        r"(?:-C\s+\S+\s+|--git-dir\s+\S+\s+|--work-tree\s+\S+\s+)*"
        r"(.+)$",
        cmd,
    )
    if match:
        return f"git {match.group(1)}"
    return None


def _extract_git_from_compound(cmd: str) -> str | None:
    """Extract git command from 'cd /path && git ...' patterns."""
    match = re.match(r"^cd\s+\S+\s*&&\s*(git\s+.+)$", cmd)
    if match:
        return match.group(1)
    return None


def _is_safe_git(normalised_cmd: str) -> bool:
    """Check if a normalised git command is read-only."""
    parts = normalised_cmd.split(None, 2)  # ['git', 'subcommand', ...]
    if len(parts) < 2:
        return False
    subcmd = parts[1]
    rest = parts[2] if len(parts) > 2 else ""

    if subcmd == "stash":
        return rest.startswith("list")
    if subcmd == "branch" and re.search(r"-[dDmM]", rest):
        return False
    if subcmd == "tag" and "-d" in rest:
        return False
    if subcmd == "config" and not re.search(r"--(?:list|get)", rest):
        return False

    return subcmd in _SAFE_GIT_SUBCOMMANDS


def _is_safe_command(cmd: str) -> bool:
    """Check if a command is read-only and safe to auto-approve."""
    stripped = cmd.strip()

    for prefix in _SAFE_INFO_PREFIXES:
        if stripped.startswith(prefix):
            return True

    for prefix in _SAFE_COMMAND_PREFIXES:
        if stripped.startswith(prefix):
            return True

    bare_safe = {"ls", "pwd", "tree", "date", "uname", "whoami", "id"}
    if stripped in bare_safe:
        return True

    return False


def _approve() -> None:
    """Output JSON to auto-approve and exit."""
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "permissionDecisionReason": "Read-only command auto-approved by hook",
            }
        },
        sys.stdout,
    )
    sys.exit(0)


def main() -> None:
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(1)

    if input_data.get("tool_name") != "Bash":
        sys.exit(0)

    command = input_data.get("tool_input", {}).get("command", "").strip()
    if not command:
        sys.exit(0)

    if _is_safe_command(command):
        _approve()

    git_cmd = None
    if command.startswith("git"):
        git_cmd = _normalise_git_command(command)
    if git_cmd is None:
        extracted = _extract_git_from_compound(command)
        if extracted:
            git_cmd = _normalise_git_command(extracted) or extracted

    if git_cmd and _is_safe_git(git_cmd):
        _approve()

    # Fall through to normal permission system
    sys.exit(0)


if __name__ == "__main__":
    main()