---
description: "Implement/change a feature (world-class Elixir; arch-first; code-focused; small diffs; always plan+patch)"
---

IN:
  FEATURE=<name>;
  ENTRY=<module|file>;
  CTX=<docs/features/<slug>.md|paste|file list|empty>;
  DESCRIPTION=<text>;

RULES:
  - Read context first (CTX + ENTRY + search in repo). If CTX is empty, infer from ENTRY; if still ambiguous, state assumptions (short) and proceed with safest minimal change.
  - Follow project standards: naming, folder layout, boundaries, existing patterns; reuse helpers/behaviours; no new deps unless explicitly asked.
  - Always output PLAN then unified diff (plan+patch only).
  - Small PR discipline: minimal diffs; avoid rewrites. If change is large, propose Phase 1/2/3 in PLAN; implement Phase 1 only.
  - No renames or reformatting unless strictly necessary for the feature.
  - No unrelated refactors.
  - Avoid moving code across boundaries unless explicitly asked.

ARCHITECTURE ORDER:
  - entry -> orchestration -> domain -> persistence -> context/adapters
  - Keep entrypoints thin. Put coordination in orchestration. Keep domain pure. Push IO/async to edges.

API / RETURN CONTRACTS:
  - Prefer {:ok, t} | {:error, reason}. Avoid nil. Avoid side-effects in domain. Normalize external errors at boundaries.
  - Preserve upstream reasons; don't swallow. No broad rescue.
  - Prefer consistent reason shapes (pick existing repo pattern; otherwise use this minimal set):
      - :not_found
      - :invalid_params
      - :conflict
      - :unauthorized | :forbidden (only if auth-related)
      - :timeout | :rate_limited (only if external IO)
      - {:external, provider, detail} (provider = atom/string; detail = stable term)
      - {:changeset, changeset} OR {:error, %Ecto.Changeset{}} (match repo conventions)

CONTROL FLOW:
  - Prefer pattern matching + function heads.
  - Use `with` for linear happy path; `case` for tagged tuples; `cond` only when guards aren't enough (rare).
  - No catch-alls that hide failures. Make non-exhaustive matches explicit.

FUNCTIONS / MODULES:
  - Functions small and single-purpose; split orchestration into private step functions; keep transforms pure.
  - Name by intent. Reduce nesting/cyclomatic complexity. Avoid boolean params that flip behavior.

PERSISTENCE / QUERIES:
  - Avoid Repo calls in loops; batch + preload; avoid N+1.
  - Compose Ecto queries via helper fns (queryable in/queryable out); keep queries reusable.
  - Select only needed fields.
  - Use explicit transactions when multi-write; use Ecto.Multi if repo uses it.
  - Avoid "fetch-all then filter" when DB can do it.

ASYNC / OBAN:
  - Prefer Oban for durable work; Task only for short-lived, supervised, bounded concurrency.
  - Never spawn unbounded tasks. Set timeouts/max_concurrency. Ensure cancellation/cleanup.
  - Keep jobs idempotent; avoid double-enqueue; respect existing queue names + limits; don't raise queue sizes without considering DB pool/external limits/throughput.

CACHE / MEMO:
  - Only if project already has a cache layer.
  - Prefer request-scoped memo (pass a map/ctx) or batching. Avoid process dictionary.
  - Don't introduce global caches without invalidation strategy.

CODE STYLE:
  - No inline comments in code (no #, no /* */). Keep code comment-free.
  - No docs.

PLAN FORMAT (tight):
  - Goal:
  - Touched files:
  - Key decisions (boundaries/contracts):
  - Risks / rollout (if any):

IMPLEMENTATION CHECKLIST (do, don't narrate):
  - Locate entrypoints from ENTRY; map call chain; identify domain boundary and persistence boundary.
  - Design minimal change respecting arch order; keep orchestration readable with private step functions.
  - Persistence: adjust schemas/changesets/queries only as needed; validate early; constrain writes; explicit tx for multi-write.
  - External IO/async: isolate adapter/worker; normalize responses; bounded concurrency; stable job args; idempotency/uniqueness where repo already does it.
  - Query hygiene: composable query fns; batch/preload; avoid repeated Repo.one/all; avoid loading unused columns.
  - Self-review: naming, pattern matches, error tuples, boundary purity, async safety, query count, diff size, no churn.

OUTPUT:
  - PLAN (3–12 bullets, max ~1200 chars) then unified diff.
  - No commentary outside contract.

POST (ask):
  - Prompt user to run quality gates on changed files:
      mix format && mix compile --warnings-as-errors && mix credo --strict

LEARNINGS (self-improvement cycle):
  - Before running, read and respect ALL bullets below.
  - After running, if the output required manual fixes or missed something,
    append ONE concise bullet: - <what went wrong> -> <how to avoid it>
  - Keep each bullet to 1 line. No refactors to the command itself.

EX:
  /write FEATURE="Data Pipeline" ENTRY="Elder.Pipeline" CTX="docs/features/data-pipeline.md" DESCRIPTION="Implement a transform step that normalizes input maps; return {:error, :invalid_params} on bad input."
