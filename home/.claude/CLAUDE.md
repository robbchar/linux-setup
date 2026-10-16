Senior full-stack developer, frontend-leaning: React, TypeScript, Tailwind, Radix.

## General

- Use US English.
- If there may not be a single correct answer, say so. Call out real trade-offs (performance, DX, accessibility).
- For anything beyond trivial edits (formatting, renames, comments), confirm the problem and agree on a plan before implementing.
- Use the latest versions unless there's a reason not to. For JS/TS, use the latest Yarn.

## Library docs

- Context7 is the source of truth for library APIs, config options, and behavior that is version-specific, recently changed, or not already in the codebase. Verify there before answering.

## Git & PRs

- New or unrelated work goes on a new branch (`intent/context-name`), in a worktree under `.ignored/worktrees/`.
- Create PRs as drafts.
- For PR review comments, propose the fix before implementing.
- For Linear tickets, read the issue's comments too.
- PRs must be up to date with their base before merging. Before merging, or calling a PR ready to merge, check it isn't behind; if it is, sync it and wait for CI on the new head. Two PRs that each pass alone can still break main together.

## Code

- Idiomatic, strongly typed TS: infer obvious types; `unknown` over `any`.
- Apply the design-principles, gof-patterns, and solid-principles skills where they fit; typescript-best-practices only when it doesn't add noise.
- Comments: 1–2 terse lines, no prose, no references to anything outside the repo.

## Tests

- Behavior changes need tests; a feature isn't done without them.
- TS/JS: colocate tests (`Feature.tsx` → `Feature.test.tsx`), no `tests/` directory. Python: follow the project's layout (usually a top-level `tests/`).
- Never run tests in watch mode (e.g. `vitest --run`).

## Docs

- Docs are markdown in `/docs` at the repo root, or in the app's own `docs/` when monorepo work is app-specific.
- Treat docs as a living wiki: update them when architecture, data flow, public APIs, or user-facing behavior change; skip implementation details; flag stale docs before calling work done.
- Prefer anchor docs (README.md, ARCHITECTURE.md, DECISIONS.md) plus focused per-feature docs. Split any doc that gets long and link the pieces.
- Superpowers plans/specs go in `.ignored/superpowers/`, not `docs/superpowers/`.

## Context discipline

- Delegate exploration: codebase searches, "where is X", or anything reading >3 files or >500 lines goes to a subagent. Read only what you'll edit.
- Subagents return `path:line` anchors with one line of reasoning each — no file dumps or restated code.
- "Found nothing" is a complete result; report it and stop.
