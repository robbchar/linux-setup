#!/usr/bin/env python3
"""Report which git worktrees have live Claude Code sessions working in them.

Reads two things Claude Code already maintains: the session roster at
~/.claude/sessions/<pid>.json for identity and liveness, and each session's
transcript for the directory it is currently working in. Nothing is written.
"""
import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# One rev-parse yields the worktree root, both git dirs, and the branch.
# --path-format=absolute matters: without it git mixes relative and absolute
# output depending on the working directory, and a nested main checkout then
# looks like a linked worktree.
GIT_REV_PARSE_ARGS = [
    "rev-parse",
    "--path-format=absolute",
    "--show-toplevel",
    "--git-dir",
    "--git-common-dir",
    "--path-format=relative",
    "--abbrev-ref",
    "HEAD",
]


def describe_dir(path, run=subprocess.run):
    """Classify a directory, or None if it is not inside a git repository.

    'linked' is True for a worktree made with `git worktree add` and False for
    the repository's main checkout. A linked worktree is the only case where
    the git dir and the common git dir differ.
    """
    try:
        result = run(
            ["git", "-C", str(path), *GIT_REV_PARSE_ARGS],
            capture_output=True,
            text=True,
        )
    except OSError:
        return None
    if result.returncode != 0:
        return None
    lines = [line.strip() for line in result.stdout.strip().splitlines()]
    if len(lines) < 4:
        return None
    toplevel, git_dir, common_dir, branch = lines[:4]
    return {
        "toplevel": toplevel,
        "branch": branch,
        "linked": git_dir != common_dir,
    }


def memoize_by_path(describe):
    """Cache a path lookup, so walking a transcript costs one git call per dir."""
    cache = {}

    def wrapped(path):
        key = str(path)
        if key not in cache:
            cache[key] = describe(key)
        return cache[key]

    return wrapped


# Transcripts reach several megabytes. Only the recent end is interesting.
TAIL_BYTES = 256 * 1024

# Widened window used only when the cheap tail read fails to find a linked
# worktree. See resolve_location for why that can happen.
WIDE_TAIL_BYTES = TAIL_BYTES * 8


def read_tail_records(path, tail_bytes=TAIL_BYTES):
    """Parse JSON records from the tail of a transcript, oldest first.

    After seeking into the middle of the file the first line is almost
    certainly a partial record, so it is discarded. A file smaller than
    tail_bytes is read whole and keeps its first line.
    """
    path = Path(path)
    try:
        size = path.stat().st_size
        with path.open("rb") as handle:
            if size > tail_bytes:
                handle.seek(size - tail_bytes)
                handle.readline()
            blob = handle.read()
    except OSError:
        return []
    records = []
    for line in blob.decode("utf-8", errors="replace").splitlines():
        try:
            parsed = json.loads(line)
        except ValueError:
            continue
        if isinstance(parsed, dict):
            records.append(parsed)
    return records


def current_location(records, describe):
    """Where a session is working now, or None if it never recorded a directory.

    Sessions periodically reset their shell back to the repository root, so the
    newest cwd of any kind is not the answer: a session that spent all day in a
    worktree can end its transcript at the root. Preferring the newest linked
    worktree, and falling back to the newest directory of any kind, reports
    those sessions where the work actually happened.
    """
    fallback = None
    for entry in reversed(records):
        cwd = entry.get("cwd")
        if not cwd:
            continue
        info = describe(cwd)
        if info is None:
            continue
        location = {
            "cwd": cwd,
            "toplevel": info["toplevel"],
            "branch": info["branch"],
            "linked": info["linked"],
            "timestamp": entry.get("timestamp"),
        }
        if info["linked"]:
            return location
        if fallback is None:
            fallback = location
    return fallback


def resolve_location(transcript, describe, tail_bytes=TAIL_BYTES,
                     wide_tail_bytes=WIDE_TAIL_BYTES):
    """Where a session is working now, widening the read if the tail lies.

    read_tail_records seeks into the file and discards whatever partial line
    it lands on. A single record larger than the window consumes the whole
    seek target: the discarded partial line is actually the tail of that
    giant record, so every record before it, including the linked-worktree
    cwd this function exists to find, is lost. If that giant record happens
    to be followed only by routine root-reset records, the cheap read reports
    a worktree session as a root session.

    The fix is to re-read with a much larger window whenever the cheap read's
    answer is not a linked worktree, and prefer that answer if it is. This
    only runs on the rare failure path, so the common case still touches at
    most tail_bytes.
    """
    cheap = current_location(read_tail_records(transcript, tail_bytes), describe)
    if cheap is not None and cheap["linked"]:
        return cheap
    wide = current_location(read_tail_records(transcript, wide_tail_bytes), describe)
    if wide is not None and wide["linked"]:
        return wide
    return cheap


SURFACES = {"claude-desktop": "desktop", "claude-vscode": "vscode"}


def read_roster(sessions_dir):
    """Parse the session roster Claude Code keeps at ~/.claude/sessions.

    Its 'cwd' is the frozen launch directory and is deliberately ignored: only
    identity, name, surface, and pid are useful here. Unreadable entries are
    skipped so one bad file cannot empty the listing.
    """
    entries = []
    for path in sorted(Path(sessions_dir).glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if not isinstance(data, dict):
            continue
        pid, session_id = data.get("pid"), data.get("sessionId")
        if not isinstance(pid, int) or not session_id:
            continue
        entrypoint = data.get("entrypoint") or "?"
        entries.append({
            "pid": pid,
            "session_id": session_id,
            "name": data.get("name") or session_id.split("-")[0],
            "surface": SURFACES.get(entrypoint, entrypoint),
            "proc_start": data.get("procStart"),
        })
    return entries


def proc_start_time(pid, proc_root="/proc"):
    """A process's start time in clock ticks since boot, or None if it is gone.

    Field 22 of /proc/<pid>/stat. The command name (field 2) is wrapped in
    parentheses and may itself contain spaces or ')', so fields are counted
    from after the last ')'.
    """
    try:
        with open(f"{proc_root}/{pid}/stat", encoding="utf-8",
                  errors="replace") as handle:
            stat = handle.read()
    except OSError:
        return None
    fields = stat[stat.rfind(")") + 2:].split()
    # fields[0] is field 3 (state), so field 22 is fields[19].
    return fields[19] if len(fields) > 19 else None


def pid_alive(pid, proc_start=None, proc_root="/proc"):
    """True if the session's process is still running.

    Reads /proc rather than shelling out to ps: a subprocess per session would
    dominate the runtime of the whole command. Linux recycles pids, so when the
    roster recorded the process start time (its 'procStart'), a live pid with a
    different start time is someone else's process and counts as dead.
    """
    started = proc_start_time(pid, proc_root)
    if started is None:
        return False
    return proc_start is None or str(proc_start) == started


def find_transcript(projects_dir, session_id):
    """Locate a session's transcript across every project directory."""
    for path in Path(projects_dir).glob(f"*/{session_id}.jsonl"):
        return path
    return None


def worktree_label(row):
    """Display name for a row's directory, marking the main checkout."""
    name = os.path.basename(row["toplevel"].rstrip("/"))
    return name if row["linked"] else f"(root) {name}"


def humanize_age(seconds):
    """Compact age: 45s, 12m, 3h, 2d."""
    if seconds < 60:
        return f"{int(seconds)}s"
    if seconds < 3600:
        return f"{int(seconds // 60)}m"
    if seconds < 86400:
        return f"{int(seconds // 3600)}h"
    return f"{int(seconds // 86400)}d"


def age_seconds(timestamp, now):
    """Seconds between a transcript timestamp and now, or None if unusable."""
    if not timestamp:
        return None
    try:
        moment = datetime.fromisoformat(str(timestamp).replace("Z", "+00:00"))
    except ValueError:
        return None
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=timezone.utc)
    return (now - moment).total_seconds()


def collect_rows(sessions_dir, projects_dir, include_dead=False,
                 is_alive=pid_alive, describe=None):
    """One row per live session that has recorded a directory."""
    describe = memoize_by_path(describe or describe_dir)
    rows = []
    for session in read_roster(sessions_dir):
        if not include_dead and not is_alive(session["pid"], session["proc_start"]):
            continue
        transcript = find_transcript(projects_dir, session["session_id"])
        if transcript is None:
            continue
        location = resolve_location(transcript, describe)
        if location is None:
            continue
        rows.append({**session, **location})
    return rows


HEADERS = ("WORKTREE", "BRANCH", "LAST SEEN", "SESSION")


def format_table(rows, now):
    """Render rows grouped by worktree, groups newest-activity-first.

    All rows for one worktree are kept adjacent (its label prints once, on
    the group's first row) rather than sorting every row independently by
    age: interleaving another worktree's row between two of this one's would
    let a blank label be misread as belonging to whichever row precedes it.
    Within a group, rows are newest first; groups are ordered by their own
    newest row so the worktree with the most recent activity leads the table.
    """
    if not rows:
        return "No live sessions in a worktree."

    def age_of(row):
        age = age_seconds(row.get("timestamp"), now)
        return age if age is not None else float("inf")

    groups = {}
    group_order = []
    for row in rows:
        key = row["toplevel"]
        if key not in groups:
            groups[key] = []
            group_order.append(key)
        groups[key].append(row)

    for group_rows in groups.values():
        group_rows.sort(key=age_of)
    group_order.sort(key=lambda key: age_of(groups[key][0]))

    cells = []
    for key in group_order:
        for index, row in enumerate(groups[key]):
            label = worktree_label(row)
            branch = row.get("branch") or "?"
            if branch == "HEAD":
                branch = "(detached)"
            age = age_seconds(row.get("timestamp"), now)
            cells.append((
                label if index == 0 else "",
                branch,
                humanize_age(age) if age is not None else "?",
                f"{row['name']}  {row['surface']}",
            ))

    widths = [max(len(HEADERS[i]), max(len(c[i]) for c in cells))
              for i in range(len(HEADERS))]
    lines = ["  ".join(HEADERS[i].ljust(widths[i]) for i in range(len(HEADERS))).rstrip()]
    for cell in cells:
        lines.append("  ".join(cell[i].ljust(widths[i])
                               for i in range(len(HEADERS))).rstrip())
    return "\n".join(lines)


SESSIONS_DIR = os.path.expanduser("~/.claude/sessions")
PROJECTS_DIR = os.path.expanduser("~/.claude/projects")


class ResolutionError(Exception):
    """A worktree name matched nothing, or more than one thing."""


def resolve_path(rows, query):
    """Absolute path of the worktree named by query, or a unique prefix of it.

    Two different rows can share a basename: two live sessions in the same
    worktree (fine, they carry the same toplevel), or two distinct worktrees
    that happen to have the same directory name (not fine, and not
    hypothetical: 'be' already exists as a worktree name in more than one
    repository). A basename backed by more than one distinct toplevel is
    ambiguous and must raise rather than silently pick whichever row came
    first, which is what a plain setdefault(basename, toplevel) would do.

    An empty or whitespace-only query is rejected outright. Every name starts
    with "", so a blank query would otherwise match anything, and with
    exactly one live worktree it would resolve silently: `wt cd` with a
    forgotten argument would move the caller somewhere they never named.
    """
    if not query or not query.strip():
        raise ResolutionError("no worktree name given")
    toplevels_by_name = {}
    for row in rows:
        name = os.path.basename(row["toplevel"].rstrip("/"))
        toplevels_by_name.setdefault(name, set()).add(row["toplevel"])

    def resolve_name(name):
        candidates = sorted(toplevels_by_name[name])
        if len(candidates) > 1:
            raise ResolutionError(
                f"'{query}' matches more than one worktree named '{name}': "
                f"{', '.join(candidates)}")
        return candidates[0]

    if query in toplevels_by_name:
        return resolve_name(query)
    matches = sorted(name for name in toplevels_by_name if name.startswith(query))
    if not matches:
        raise ResolutionError(f"no live session in a worktree matching '{query}'")
    if len(matches) > 1:
        raise ResolutionError(f"'{query}' is ambiguous: {', '.join(matches)}")
    return resolve_name(matches[0])


def parse_worktree_list(porcelain):
    """Every worktree git knows about, from `git worktree list --porcelain`.

    Records are blank-line separated; `branch` is absent on a detached head, so
    it stays None rather than being faked from the HEAD line.
    """
    entries = []
    for block in porcelain.strip().split("\n\n"):
        path, branch, prunable = "", None, False
        for line in block.splitlines():
            if line.startswith("worktree "):
                path = line[len("worktree "):]
            elif line.startswith("branch refs/heads/"):
                branch = line[len("branch refs/heads/"):]
            elif line.startswith("prunable"):
                prunable = True
        if path:
            entries.append({"path": path, "branch": branch, "prunable": prunable})
    return entries


#: Where to look when the current directory's repository does not have the
#: branch. Baked in rather than configurable: this is a personal tool with one
#: main project, and an env var or config file would be indirection with a
#: single consumer.
DEFAULT_REPO = Path.home() / "Projects" / "elevate"


def locate_worktree(ref, run=subprocess.run, default_repo=DEFAULT_REPO):
    """The worktree for a ref, searching the current repo then the default one.

    Returns (path, fell_back). Requiring the caller to already be standing in
    the right repository would defeat the point: the question this answers is
    "which directory should I be in".

    The retry is on any failure, not just "cwd is not a repository". A perfectly
    good repo that simply lacks the branch is the common case, and a PR number
    resolves against whichever repo `gh` runs in, so the fallback re-resolves
    the ref rather than reusing what the first attempt could not produce.
    """
    def find(cwd):
        return worktree_for_branch(resolve_branch(ref, run=run, cwd=cwd),
                                   run=run, cwd=cwd)

    try:
        return find(None), False
    except ResolutionError as first:
        if default_repo is None or not Path(default_repo).is_dir():
            raise
        try:
            return find(str(default_repo)), True
        except ResolutionError as second:
            raise ResolutionError(
                f"{second} (also looked in {default_repo}; here: {first})") from None


def resolve_branch(ref, run=subprocess.run, cwd=None):
    """A branch name from either a branch name or a pull request number.

    An all-digits ref is treated as a PR, which means a branch literally named
    "345" is unreachable this way. Nothing can tell those apart from the string,
    and PR numbers are what people have to hand.
    """
    if not ref.isdigit():
        return ref
    result = run(["gh", "pr", "view", ref, "--json", "headRefName",
                  "-q", ".headRefName"],
                 capture_output=True, text=True, cwd=cwd)
    if result.returncode != 0:
        raise ResolutionError(
            f"could not read pull request {ref}: {(result.stderr or '').strip()}")
    branch = result.stdout.strip()
    if not branch:
        raise ResolutionError(f"pull request {ref} reported no head branch")
    return branch


def worktree_for_branch(branch, run=subprocess.run, cwd=None):
    """The worktree checked out on a branch, main checkout included.

    A lookup, deliberately, not `git switch`: switching mutates whichever
    checkout you happen to be standing in when the branch is not already out
    somewhere, which can pull it from under a session working there.
    """
    result = run(["git", "worktree", "list", "--porcelain"],
                 capture_output=True, text=True, cwd=cwd)
    if result.returncode != 0:
        raise ResolutionError(
            f"not inside a git repository: {(result.stderr or '').strip()}")
    for entry in parse_worktree_list(result.stdout):
        if entry["branch"] != branch:
            continue
        if entry["prunable"]:
            raise ResolutionError(
                f"the worktree for {branch} is gone ({entry['path']}); "
                "run `git worktree prune`")
        return entry["path"]
    raise ResolutionError(f"no worktree has {branch} checked out")


def _collect(include_dead=False):
    return collect_rows(SESSIONS_DIR, PROJECTS_DIR, include_dead=include_dead)


def main(argv=None, collect=_collect, run=subprocess.run):
    parser = argparse.ArgumentParser(
        prog="wt",
        description="Show which git worktrees have live Claude Code sessions.")
    subcommands = parser.add_subparsers(dest="command")

    listing = subcommands.add_parser("ls", help="list worktrees with live sessions")
    listing.add_argument("--all", action="store_true",
                         help="include sessions whose process has exited")

    path_command = subcommands.add_parser("path", help="print a worktree's path")
    path_command.add_argument("name", help="worktree name or a unique prefix")

    branch_command = subcommands.add_parser(
        "branch",
        help="print the worktree path holding a branch, or a PR's head branch")
    branch_command.add_argument("ref", help="branch name or pull request number")

    args = parser.parse_args(argv)

    if args.command == "branch":
        try:
            path, fell_back = locate_worktree(args.ref, run=run)
        except ResolutionError as error:
            print(f"wt: {error}", file=sys.stderr)
            return 1
        # stderr, not stdout: the shell function cds to whatever stdout holds.
        if fell_back:
            print(f"wt: searched {DEFAULT_REPO}", file=sys.stderr)
        print(path)
        return 0

    if args.command == "path":
        try:
            print(resolve_path(collect(include_dead=False), args.name))
        except ResolutionError as error:
            print(f"wt: {error}", file=sys.stderr)
            return 1
        return 0

    print(format_table(collect(include_dead=getattr(args, "all", False)),
                       datetime.now(timezone.utc)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
