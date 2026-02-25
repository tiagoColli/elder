---
description: "Write/update documentation (Elixir @moduledoc/@doc; concise; flow+contracts; doc-only patch; always plan+patch)"
---

IN:
  FEATURE=<optional name>;
  TARGETS=<file list|module list|glob>;
  CTX=<optional docs/features/<slug>.md|paste|empty>;

RULES:
  - Doc-only change: update/add @moduledoc/@doc/@typedoc.
    - Add @spec only when missing for public functions in modules you touch (prefer consistency: if one public fn in a touched module has/needs @spec, ensure all public fns in that module have @spec unless repo clearly avoids specs).
    - No behavior changes. No refactors. No new dependencies.
    - No renames or reformatting unless strictly necessary for the doc change.
    - Avoid moving code across boundaries unless explicitly asked.
  - No inline comments in code (no #, no /* */). Documentation only via @moduledoc/@doc/@typedoc.
  - Derive docs from actual code + CTX. Do not speculate. If something is unclear, document only the contract and observable behavior.

MODULE CLASSIFICATION:
  - Orchestrator/main module: coordinates steps, calls multiple boundaries, or is a primary entrypoint.
  - Internal module: focused helper, adapter, schema, query, or small domain utility.
  - If uncertain, treat as internal.

CONTENT FOCUS:
  - Orchestrators/main modules:
    - @moduledoc: purpose + 1–2 line flow summary (no long narratives).
    - @doc: goal, params, returns, errors (shape), side-effects (only if relevant), invariants/assumptions (brief).
  - Internal modules:
    - @moduledoc: responsibility + contract only (do not mention who uses it).
    - @doc: what it does; params/returns/errors only when needed for clarity.

ERROR / RETURN SHAPES:
  - Reflect real return contracts found in code. Preserve existing reason shapes.
  - If you need to describe reasons and the repo has no explicit pattern, prefer a minimal stable set:
      :not_found
      :invalid_params
      :conflict
      :unauthorized | :forbidden (only if auth-related)
      :timeout | :rate_limited (only if external IO)
      {:external, provider, detail}
      {:changeset, %Ecto.Changeset{}}
  - Do not invent new reason taxonomies.

EXAMPLES:
  - Orchestrators/main modules:
    - Exactly 1 doctest-style example block AND exactly 1 copy/paste IEx line (plain expression, no "iex>" prompt).
    - Examples must be derived from a real public API in the module (pick the primary public function).
    - Keep args minimal and generic; keep return shape realistic (e.g., {:ok, _} | {:error, _}).
    - Do not print large structs/maps; prefer pattern matches or small scalar outputs.
    - If a safe, realistic example is not possible without inventing behavior, omit examples and state this briefly in PLAN.
  - Internal modules:
    - Optional 0–1 small doctest example only if it clarifies params/return. Never more than 1.

DOC SIZE / STYLE:
  - Follow existing project doc style: tone, headings, naming, code fences.
  - Prefer bullets. Cap each @doc to ~6–10 lines unless truly necessary.
  - Keep @moduledoc tight. Avoid reflowing unrelated docs.

OUTPUT:
  - Always output PLAN then unified diff.
  - No commentary outside contract.

PLAN FORMAT (tight):
  - Goal:
  - Modules/files:
  - What will be added/updated (@moduledoc/@doc/@typedoc/@spec):
  - Examples (where/which API):
  - Risks (hallucination/noise):

LEARNINGS (self-improvement cycle):
  - Before running, read and respect ALL bullets below.
  - After running, if the output required manual fixes or missed something,
    append ONE concise bullet: - <what went wrong> -> <how to avoid it>
  - Keep each bullet to 1 line. No refactors to the command itself.

EX:
  /docs FEATURE="Pipeline" TARGETS="lib/elder/pipeline/**.ex" CTX="docs/features/pipeline.md"
