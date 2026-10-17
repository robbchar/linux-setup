#!/usr/bin/env bash
# Claude Code subagent status line
# Renders one row per subagent: name | type | status | token bar | elapsed
#
# Wire up in ~/.claude/settings.json:
#   "subagentStatusLine": { "type": "command", "command": "~/.claude/subagent-statusline.sh" }

PYTHON=$(command -v python3 python 2>/dev/null | head -1)

input=$(cat)

# Emit one JSON line per task row to stdout.
# The content string is rendered as-is (ANSI codes work).
printf '%s' "$input" | "$PYTHON" - <<'PYEOF'
import sys, json, math, time

ESC   = "\033"
RESET = ESC + "[0m"
DIM   = ESC + "[2m"
BOLD  = ESC + "[1m"

def fg(r, g, b):       return ESC + f"[38;2;{r};{g};{b}m"
def bg_none():         return ""

GREEN  = fg(78, 201, 78)
YELLOW = fg(232, 184, 107)
RED    = fg(224, 95, 95)
CYAN   = fg(127, 184, 232)
GRAY   = fg(120, 120, 110)

def color_for_pct(pct):
    if pct >= 90: return RED
    if pct >= 70: return YELLOW
    return GREEN

def make_bar(pct, width=10):
    pct = max(0, min(100, pct))
    filled = round(pct * width / 100)
    empty  = width - filled
    c = color_for_pct(pct)
    return c + "▓" * filled + RESET + DIM + "░" * empty + RESET

def fmt_elapsed(start_ms):
    if not start_ms:
        return ""
    elapsed_s = (time.time() * 1000 - start_ms) / 1000
    if elapsed_s < 60:
        return f"{elapsed_s:.0f}s"
    return f"{elapsed_s/60:.1f}m"

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tasks = d.get("tasks", [])
if not tasks:
    sys.exit(0)

for task in tasks:
    task_id   = task.get("id", "")
    name      = task.get("name") or task.get("label") or "agent"
    status    = task.get("status", "running")
    tok_count = task.get("tokenCount") or 0
    tok_samp  = task.get("tokenSamples") or []
    start_ms  = task.get("startTime")
    agent_type = task.get("type", "")

    # Estimate context % from tokenCount (Opus/Sonnet = 200k window)
    CTX_WINDOW = 200_000
    ctx_pct = min(100, round(tok_count / CTX_WINDOW * 100)) if tok_count else 0

    # Status indicator
    if status in ("complete", "done", "success"):
        indicator = GREEN + "✓" + RESET
        bar_color = GREEN
    elif status in ("error", "failed"):
        indicator = RED + "✗" + RESET
        bar_color = RED
    else:
        indicator = YELLOW + "⟳" + RESET
        bar_color = None  # let make_bar pick by pct

    bar = make_bar(ctx_pct)
    elapsed = fmt_elapsed(start_ms)

    # Truncate long names
    display_name = (name[:22] + "…") if len(name) > 23 else name

    # type tag (short)
    type_tag = ""
    if agent_type:
        short_type = agent_type[:8]
        type_tag = GRAY + f"[{short_type}]" + RESET + " "

    tok_str = ""
    if tok_count:
        tok_str = GRAY + f" {tok_count:,}tok" + RESET

    elapsed_str = ""
    if elapsed:
        elapsed_str = GRAY + f" {elapsed}" + RESET

    ctx_str = ""
    if ctx_pct:
        c = color_for_pct(ctx_pct)
        ctx_str = f" ctx:{bar} {c}{ctx_pct}%{RESET}"

    content = f"  {indicator} {type_tag}{BOLD}{display_name}{RESET}{ctx_str}{tok_str}{elapsed_str}"
    print(json.dumps({"id": task_id, "content": content}))

PYEOF
