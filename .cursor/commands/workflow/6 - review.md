---
description: "Review local changes (code+docs+logs+tests) -> write docs/reviews/<slug>.md (report only)"
---

IN:
  FEATURE=<optional name>;
  TARGETS=<optional file list|glob>;
  CTX=<optional docs/features/<slug>.md|paste|empty>;
  BASE_BRANCH=main(default);

RULES:
  - Review only:
    - Do NOT change production code, tests, docs, or logs.
    - Only create/update a single report file under docs/reviews/<slug>.md.
    - No new dependencies. No refactors. No renames/reformatting. No boundary moves.

  - Mode selection (implicit):
    - If TARGETS is provided and non-empty:
      - Review exactly TARGETS (plus any directly-associated Elixir test/doc/log files if they are in TARGETS).
      - Do not use git diff.
    - If TARGETS is missing or empty:
      - Use git diff mode based on BASE_BRANCH.
      - Before running/using git, ask the user to provide the outputs (NEEDS). Do not proceed without file list evidence.

  - Be skeptical:
    - Assume nothing works until proven.
    - Hunt for crashes, bad matches, nil leaks, wrong contracts, missed edges, async hazards, query issues, boundary violations, inconsistent patterns, hidden side-effects, and "looks ok" AI code.

  - Check against house rules:
    - No inline comments.
    - Clear return tuples; stable error reason shapes; no nil contracts.
    - Small functions; minimal nesting; intentful naming; reuse existing patterns.
    - IO at edges; domain purity; no hidden side-effects.
    - Composable Ecto queries; no Repo calls in loops; avoid N+1; explicit transactions for multi-write.
    - Task usage bounded/supervised; no uncontrolled processes.
    - Oban idempotency/uniqueness/queue safety; avoid double enqueue hazards; stable args.
    - Logs meaningful and non-chatty; no payload dumps; stable identifiers only.
    - Docs concise and accurate to code.
    - Tests cover happy/error/edge; not "just pass"; never weaken assertions to bypass failures.

  - Report must be actionable:
    - Each finding includes severity (MUST/SHOULD/NIT), file(s), risk, evidence, and concrete fix guidance.
    - No large rewrites; if big, propose Phase 1/2, with Phase 1 small and safe.
    - Never suggest weakening tests to "make them pass".

SEVERITY RUBRIC:
  - MUST: correctness/contract break, crashes, data loss/corruption, security/privacy risk, concurrency hazards, unsafe async, broken idempotency, query explosions, production incident risk.
  - SHOULD: maintainability/performance/observability risks likely to become incidents; inconsistent patterns; unclear boundaries; weak tests likely to regress.
  - NIT: readability/style/consistency issues with low risk.

DIAGNOSTIC RUBRIC:
  - FAIL: any MUST exists.
  - WARN: no MUST, but one or more SHOULD exists.
  - PASS: only NITS or no findings.

REFERENCING CODE:
  - Prefer file:line when available. If line numbers aren't available, use file + module/function name as locator.
  - Do not paste large code blocks into the report; keep evidence to short descriptions.

SLUG:
  - local-<feature_or_branch>-<YYYYMMDD> (kebab).
  - If FEATURE missing, use current branch name if known; otherwise use "local".
  - If a report with the same slug already exists, update it instead of creating a new file.

OUTPUT:
  - Always output PLAN then unified diff for docs/reviews/<slug>.md only.
  - No commentary outside the report.

PLAN FORMAT (tight):
  - Goal:
  - Mode (targets|git diff):
  - Scope (files):
  - Context:
  - Review focus areas:
  - Output file:

NEEDS (no diff):
  - When TARGETS is empty:
    - Ask user to paste file lists from these commands (based on BASE_BRANCH) and then proceed:
      - Staged: git diff --cached --name-only
      - Unstaged: git diff --name-only
      - Branch diff: git diff --name-only <BASE_BRANCH>...HEAD
      - If still empty: git diff --name-only HEAD~1..HEAD
    - Also ask for current branch name if FEATURE is empty and branch is unknown:
      - git rev-parse --abbrev-ref HEAD

POST (ask mode):
  - Prompt user to run quality gates:
      mix format && mix compile --warnings-as-errors && mix credo --strict
      mix test

REPORT TEMPLATE (tight):
# Review: <FEATURE or branch> (<YYYY-MM-DD>)
## Scope
- Files:
- Context:
## Diagnostic
- Overall: PASS|WARN|FAIL
- MUST:
- SHOULD:
- NITS:
## Findings (ordered)
### MUST
- <title> | <file:line or file + fn> | Risk:<...> | Evidence:<...> | Fix:<...>
### SHOULD
- ...
### NITS
- ...
## Deep checks
- Contracts/Errors:
- Async/Oban:
- Queries/DB:
- Docs:
- Logs:
- Tests:
## Suggested next actions
- Phase 1:
- Phase 2:

LEARNINGS (self-improvement cycle):
  - Before running, read and respect ALL bullets below.
  - After running, if the output required manual fixes or missed something,
    append ONE concise bullet: - <what went wrong> -> <how to avoid it>
  - Keep each bullet to 1 line. No refactors to the command itself.

EX:
  /review FEATURE="Pipeline" TARGETS="lib/elder/pipeline/**.ex test/elder/pipeline/**.exs" CTX="docs/features/pipeline.md" BASE_BRANCH=main
  /review FEATURE="Pipeline" CTX="docs/features/pipeline.md" BASE_BRANCH=main
