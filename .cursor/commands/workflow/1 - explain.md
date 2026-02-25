---
description: "Explain current feature architecture -> write docs/features/<slug>.md (read-only scan)"
---

IN:
  FEATURE=<name>;
  ENTRY=<route|module|file|search>;

RULES:
  - Read-only scan only (open + search). No terminal. No refactor.
  - Only change: docs/features/<slug>.md (create/update).
  - Find related files via call chains + refs:
      module -> public API -> internal fns -> helpers
      schema -> changeset -> query
  - Describe what exists now: boundaries, flow, contracts, side-effects, errors/retries, tests.
  - Smells/risks: cite files; no fixes.

OUTPUT:
  - Unified diff touching ONLY docs/features/<slug>.md; no extra commentary.

SLUG:
  - lower kebab(FEATURE); if missing, derive from ENTRY.

DOC TEMPLATE (omit empty sections; keep tight):
# <FEATURE>
## TL;DR
- Does:
- Starts:
- Side-effects:
## Entry points
- <public fn|module> => <module.fun/arity> (file)
## File map
- entry:
- orchestration:
- domain:
- persistence:
- external IO:
- tests:
## Flow (opt)
- Steps list; add diagram only if helpful (any text/ascii; no mermaid required).
## Data/contracts
- Inputs:
- Outputs:
- Key structs/schemas:
## Errors+retries
- Errors:
- Retry/backoff:
## Tests
- Existing:
- Gaps:
## Smells/risks (no fixes)
- <smell> -> <file(s)> : <impact>
## Follow-ups
- Questions:
- Next diffs (high-level):

LEARNINGS (self-improvement cycle):
  - Before running, read and respect ALL bullets below.
  - After running, if the output required manual fixes or missed something,
    append ONE concise bullet: - <what went wrong> -> <how to avoid it>
  - Keep each bullet to 1 line. No refactors to the command itself.

EX:
  /explain FEATURE="Data Pipeline" ENTRY="Elder.Pipeline"
