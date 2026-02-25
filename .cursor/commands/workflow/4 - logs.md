---
description: "Add/adjust meaningful logs (structured; minimal; debug-useful; no behavior changes; no inline comments)"
---

IN:
  FEATURE=<name>;
  TARGETS=<file list|module list|glob>;
  CTX=<optional docs/features/<slug>.md|paste|empty>;

RULES:
  - Logs-only change: add/adjust Logger calls (and minimal local metadata helpers) without behavior changes.
    - Do not change function signatures, return values, control flow semantics, data shapes, query logic, or async behavior.
    - No new dependencies.
    - No unrelated refactors.
    - No renames or reformatting unless strictly necessary for the log change.
    - Avoid moving code across boundaries unless explicitly asked.
  - No inline comments in code (no #, no /* */). Keep code comment-free.

LOG LINE FORMAT:
  - Message is a single line string:
      "FEATURE | Step | id/count | result"
    - FEATURE: exactly FEATURE input (stable).
    - Step: short verb phrase (consistent across codebase for the same action).
    - id/count: correlation id or counter (prefer correlation id).
    - result: pick 1–2 tokens only:
        - ok
        - error:<reason_tag>
        - skip:<why>
        - count:<n>
        - ms:<n>

LOGGER METADATA (preferred in addition to message):
  - Use Logger metadata when possible for filtering/searching. Minimal schema:
      feature: FEATURE
      step: <step>
      cid: <correlation_id>
    - Optional keys (only when available and useful):
      entity_id, job_id, queue, attempt, count, ms, reason
  - Never log large structs/maps. Never dump payloads. Never log secrets/PII.
  - If logging identifiers, prefer stable scalars:
      id, external_ref, handle, filename, url host/path, job_id, entity_id

LEVELING:
  - Logger.info: start/end of critical flow, successful boundary crossings, enqueue, batch summaries.
  - Logger.warning: retries, skips, unexpected-but-handled states.
  - Logger.error: terminal failures or boundary failures immediately before returning {:error, reason}.

CORRELATION ID RULES:
  - Prefer existing ids in this order:
      request/trace id (conn assigns / telemetry / existing repo pattern)
      Oban job id + attempt
      domain entity id
  - Do not invent ids unless none exist; if you must, generate a short id scoped to the current call only and do not persist it.

MEANINGFUL ONLY:
  - Log start/end of critical flows, boundary IO (external API/db batch), enqueue/dequeue/start/end/retry/fail, skips, unexpected states.
  - Avoid noisy per-item logs in loops. Do not log inside Enum.map/each/reduce.
  - Prefer aggregated counts/durations:
      count:<n>, ms:<n>
  - Timing: use monotonic time deltas around boundary IO or batch operations when cheap.

OUTPUT:
  - Always output PLAN then unified diff.
  - No commentary outside contract.

PLAN FORMAT (tight):
  - Goal:
  - Targets (files/modules):
  - Log points (steps):
  - IDs used (correlation):
  - Risks (noise/PII):

IMPLEMENTATION CHECKLIST (do, don't narrate):
  - Find critical flow boundaries in TARGETS/CTX; add logs at: entry, before/after IO, enqueue, batch start/end, retries, terminal result.
  - Reuse existing correlation id patterns; propagate via function args/metadata when already present.
  - Keep each log line short; avoid more than 1–2 logs per function unless boundary-heavy; aggregate counts.
  - Self-review: no payload dumps, no inspect of big terms, no loop spam, consistent Step names, stable ids, correct log levels.

LEARNINGS (self-improvement cycle):
  - Before running, read and respect ALL bullets below.
  - After running, if the output required manual fixes or missed something,
    append ONE concise bullet: - <what went wrong> -> <how to avoid it>
  - Keep each bullet to 1 line. No refactors to the command itself.

EX:
  /logs FEATURE="Pipeline" TARGETS="lib/elder/pipeline/**.ex" CTX="docs/features/pipeline.md"
