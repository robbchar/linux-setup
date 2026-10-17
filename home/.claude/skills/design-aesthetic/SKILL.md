---
name: design-aesthetic
description: Robb's design sensibilities — form-follows-function, fit-for-purpose UI, restrained motion, context-appropriate density. Auto-surface when generating any UI, choosing component patterns, adding animation, or making layout decisions. Per-project tokens (colors, fonts) should override these global defaults.
---

# Design Aesthetic

Robb has a visual arts and animation background. That means two things that
pull in opposite directions: he genuinely appreciates good craft, and he has
a high enough bar that he'd rather have nothing than something done badly.

The guiding principle is **form follows function**. A UI should seamlessly
serve its purpose — like VSCode in the browser or Gmail. It just *works*,
and it takes over the space it needs without announcing itself. Details and
polish matter, but only once the thing functions correctly. Don't decorate
before it works.

---

## Color mode

**Global default:** start with light mode, designed for user preference
switching. Dark mode is added as a second pass, never bolted on. Token
structure must support both cleanly — no hardcoded hex values in components.

Robb personally uses dark mode, so dark themes should be thoughtfully
designed when they're included, not just `bg-gray-900` inversions.

**Per-project override:** some tools may be dark-primary. Set this
explicitly when starting a project.

---

## Density

Density is context-driven, not a single global setting. The rule:

- **Tool / data-heavy views** (dashboards, editors, tables, admin panels):
  tight. Information density is the feature. Think VSCode sidebar, not a
  marketing page.
- **Content / reading views** (articles, forms, onboarding): comfortable
  to airy. Whitespace serves comprehension.

Don't apply a single density setting across an entire app. Ask which mode
the current view is in.

---

## Typography

**Default (when no project font is specified):**
- UI text: system font stack — `-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`
- Code / technical content: monospace — `"JetBrains Mono", "Fira Code", "Cascadia Code", monospace`
- Upgrade to a custom font when the design genuinely warrants it, not by default

Robb likes mono fonts in text-heavy or code-adjacent contexts. Lean toward
monospace for technical UIs even when not strictly a code editor.

**Per-project override:** specify the font pair, scale, and weights here
when the project has a defined type system.

---

## Motion

**The rule:** none over bad. If an animation isn't doing real work, don't
add it. But when animation is called for, it should have personality and
be done well — not a default 300ms ease-in-out on everything.

Animation earns its place by doing one of these:
- Communicating a state change (loading, success, error transition)
- Orienting the user spatially (panel sliding in, content expanding)
- Providing feedback that something responded (button press, drag)

**Defaults when motion is appropriate:**
- Duration: short (80–160ms for micro-interactions, up to 280ms for larger
  transitions). Err fast over slow.
- Easing: ease-out for things entering, ease-in for things leaving.
  `cubic-bezier(0.16, 1, 0.3, 1)` (spring-like) for elements coming into
  focus.
- Nothing loops or draws attention to itself unprompted.

**What never animates without being explicitly asked:**
- Hover states on every interactive element
- Page-load decorative sequences
- Background elements, blobs, gradients
- Things that move while the user is trying to read

---

## Component conventions

**Buttons:**
- Hierarchy matters: one primary action per view. Secondary and tertiary
  actions should visually recede.
- Prefer subtle hover states over dramatic ones. The interaction should
  feel responsive, not theatrical.

**Cards:**
- Border over shadow as the default surface treatment. Heavy shadows
  (`drop-shadow-2xl` or `shadow-xl` on everything) is an anti-pattern.
- If a shadow is used, it should be purposeful — elevation, not decoration.

**Forms:**
- Validation on blur or submit, not on every keystroke.
- Inline error messages, not toasts for field-level errors.
- Labels above fields.

**Empty states:**
- Always include one. An empty state is not an afterthought.
- Tone matches the app — not generic "No data found." text.
- Include a clear next action.

**Loading states:**
- Skeleton screens over spinners for content areas.
- Spinners are fine for button-level feedback (form submit, etc.).

---

## Anti-patterns (do not produce without being explicitly asked)

- **Centered hero with a gradient blob** — the generic SaaS landing page
  opener. If building a marketing page, ask about the hero treatment first.
- **`shadow-2xl` / `drop-shadow-2xl` on every card** — heavy shadow stacks
  applied uniformly flatten visual hierarchy rather than creating it.
- **Reflexive hover animations** — a transition on every interactive element
  without purpose. Animation should be earned.
- **Decorating before functioning** — adding polish, gradients, or motion
  to UI that doesn't work correctly yet.
- **One density for all views** — applying comfortable spacing to a dense
  data table, or tight spacing to a reading surface.

---

## When to stop and ask

- Choosing a color palette or specific brand tokens for a new project
- Introducing a custom font (don't upgrade from system fonts without asking)
- Adding any animation beyond micro-interactions
- Choosing an icon library
- Designing the first version of a view type that hasn't appeared in the
  project yet (first form, first table, first empty state)

---

## Per-project setup

When starting a new project, add a `design-aesthetic` override in the
project's `.claude/skills/` or document these in `docs/ARCHITECTURE.md`:

- Color tokens (bg, surface, text, accent, danger, success)
- Font pair and scale
- Dark mode: supported / planned / not in scope
- Density default for this project's primary views
- Any project-specific anti-patterns or component rules
