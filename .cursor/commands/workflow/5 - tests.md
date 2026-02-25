---
description: "Generate/upgrade ExUnit tests (high coverage; realistic; project-style; no 'just pass'; always plan+patch)"
---

IN:
  FEATURE=<optional name>;
  TARGETS=<file list|module list|glob>;
  CTX=<optional docs/features/<slug>.md|paste|empty>;

RULES:
  - Primary goal: increase confidence and coverage (happy/error/edge), not "green at any cost".
  - Tests-only change:
    - Modify *_test.exs and existing test support only (e.g., test/support, existing factories/fixtures).
    - Do not change production code unless explicitly asked.
    - No new dependencies.
    - No unrelated refactors.
    - No renames or reformatting unless strictly necessary.
    - Avoid moving code across boundaries unless explicitly asked.
  - Mirror existing test style:
    - Find similar tests first and match structure, helpers, tags, naming, assertion style, and module layout.
    - Reuse DataCase/ConnCase and existing setup helpers.
    - Do not invent new helper files. Only extend existing helper modules if absolutely necessary and consistent with repo patterns.
  - Determinism and anti-flake rules:
    - Do not use Process.sleep/1.
    - Do not depend on DateTime.utc_now/0, System.system_time/0, random values, or external network.
    - Prefer assert_receive / refute_receive with explicit timeouts for message-based async.
    - If the repo already uses time control (e.g., Mox time provider, Timex shift, etc.), reuse that pattern. Otherwise, assert shapes/timestamps loosely but safely (e.g., "is a DateTime" and ordering only if deterministic).
    - Avoid order-dependent assertions unless the code guarantees ordering (otherwise sort explicitly in the test).
  - Coverage requirements:
    - Happy path: assert primary success output and key persisted side-effects (DB writes) when applicable.
    - Error path(s): assert {:error, reason} and the reason shape/tag (atom/tuple/changeset) exactly as intended.
    - Edge cases: nil/empty/invalid types/large inputs/duplicates/idempotency where relevant.
    - Regression guards: ordering, dedupe, uniqueness, idempotency, and boundary behaviors that historically break.
  - Mocks and stubs:
    - Avoid mocks unless necessary for true external boundaries (HTTP, filesystem, time, UUID, external services) or already-mocked seams in the repo.
    - Never mock pure/internal modules (contexts, schemas, query modules, domain helpers).
    - Only use mocking tools already present in the repo (e.g., Mox/Bypass). Do not introduce new mocking libraries.
  - DB hygiene:
    - Use the repo's existing sandbox/DataCase patterns.
    - Keep setup minimal and explicit; prefer setup per test over setup_all unless clearly shared and cheap.
    - Use factories/fixtures already in the repo; create realistic, readable data.

OUTPUT:
  - Always output PLAN then unified diff.
  - No commentary outside contract (except POST ask).

PLAN FORMAT (tight):
  - Goal:
  - Targets (source + tests):
  - Test cases (happy/error/edge):
  - Factories/fixtures used:
  - Mocks (if any, why):
  - Flake risks (and mitigation):

POST (ask mode):
  - Prompt user to run quality gates and tests for touched files:
      MIX_ENV=test mix compile --warnings-as-errors
      mix test <touched_test_files>

NEEDS (no diff):
  - If realistic tests cannot be written without inventing helpers/seams, output NEEDS listing exactly what inputs are required (e.g., existing factory names, boundary adapter module, or example similar test file).

LEARNINGS (self-improvement cycle):
  - Before running, read and respect ALL bullets below.
  - After running, if the output required manual fixes or missed something,
    append ONE concise bullet: - <what went wrong> -> <how to avoid it>
  - Keep each bullet to 1 line. No refactors to the command itself.

EX:
  /tests FEATURE="Pipeline" TARGETS="lib/elder/pipeline/**.ex" CTX="docs/features/pipeline.md"
