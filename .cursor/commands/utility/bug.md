---
description: "Fix a bug/regression (minimal change; contract discipline; no test-writing here) -> code patch"
---
IN:ISSUE=<brief>;ENTRY=<module|file|search>;TARGETS=<opt file list|glob>;CTX=<opt docs/features/<slug>.md|paste>;REPRO=<opt steps|failing test>;MODE=plan+patch|patch(def plan+patch)
RULES:-Bugfix only: smallest correct change; avoid opportunistic refactors; keep diff tight.-Follow project standards; reuse existing patterns; no new deps unless explicitly asked.-No inline comments in code(no #, no /* */).Docs only via @doc/@moduledoc when truly needed.-Contracts: preserve/restore intended return shapes; avoid nil; avoid broad rescue; preserve upstream error reasons; normalize errors at boundaries only.-Control flow: function heads+pattern matches first; with for linear happy path; case for tagged tuples; cond rare.-Async: ensure bounded concurrency; avoid Task storms; Oban jobs idempotent/unique where repo already does; avoid changing queue sizes; prevent retry loops/storms.-Queries: avoid Repo in loops; batch/preload; composable queries; select only needed fields; explicit tx for multi-write; avoid "fetch-all then filter".-Do not write tests here (separate command).If fix needs regression coverage, explicitly call it out in PLAN and include a ready-to-run /tests invocation line.
OUTPUT:MODE=plan+patch => PLAN(3-10 bullets,max 900 chars) then unified diff; MODE=patch => diff only.No commentary outside contract (except POST ask).
PLAN fmt(tight):-Bug:-Root cause(summary):-Fix approach:-Files:-Follow-up tests(cmd):
POST(ask mode):Prompt user to run quality gates: mix format && mix compile --warnings-as-errors && mix credo --strict; and instruct to run /tests targeting affected modules/files (or run mix test for relevant tests if provided).

EX: /bugfix ISSUE="Duplicate processing on retry" ENTRY="Elder.Pipeline.Transform.run/1" CTX="docs/features/pipeline.md" REPRO="obs: two results per item after timeout" MODE=plan+patch
