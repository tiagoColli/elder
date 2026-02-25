---
description: "Review a PR branch like GitHub (human-friendly) -> write docs/reviews/<slug>.md (report only; always plan+patch)"
---

IN:
  PR_BRANCH=<optional branch>;
  BASE_BRANCH=main(default);
  TARGETS=<optional file list|glob>;
  CTX=<optional docs/features/<slug>.md|paste|empty>;
  CHECKOUT=ask|skip(default ask);

RULES:
  - Review only:
    - Do NOT change product code/tests/docs/logs.
    - Only create/update a single report file under docs/reviews/<slug>.md.
    - No new dependencies. No refactors. No renames/reformatting. No boundary moves.

  - PR tone:
    - Write like a GitHub reviewer: respectful, concise, specific.
    - Use labels:
        MUST (blocking)
        SHOULD (non-blocking)
        NIT (style)
    - Avoid sarcasm and assumptions.
    - If intent is unclear, ask clarifying questions in the Questions section.

  - Mode selection (implicit):
    - If TARGETS is provided and non-empty:
      - Review exactly TARGETS.
      - Do not require git diff evidence.
    - If TARGETS is missing or empty:
      - Use git diff mode for BASE_BRANCH...PR branch.
      - Do not proceed without evidence (NEEDS).

  - Branch selection:
    - If PR_BRANCH is provided:
      - Review PR_BRANCH against BASE_BRANCH.
    - If PR_BRANCH is missing:
      - Review current branch against BASE_BRANCH.
    - If branch name is unknown and TARGETS is empty, output NEEDS.

  - CHECKOUT behavior:
    - If CHECKOUT=ask:
      - Do not assume the branch is checked out.
      - Require the user to either:
          a) checkout PR_BRANCH and paste git diff outputs, or
          b) paste git diff outputs without checkout (from their environment).
    - If CHECKOUT=skip:
      - Still require diff evidence when TARGETS is empty.

  - Strict correctness + maintainability checks:
    - Crashes, bad matches, nil leaks, wrong contracts/reason shapes, boundary purity violations, hidden side-effects.
    - Async hazards: unbounded tasks, non-idempotent Oban jobs, uniqueness gaps, unsafe retries.
    - Query anti-patterns: Repo in loops, N+1, fetch-all-then-filter, missing transactions for multi-write.
    - Missing or weak tests/docs/logs for changed behavior.
    - AI-flavored code smells: generic naming, oversized functions, over-abstraction, inconsistent patterns.

  - Mocks:
    - Do not default to "add mocks".
    - Only for true external boundaries or existing mocked seams in the repo.
    - Prefer real code paths and repo factories/fixtures.

  - No "broken tests loop":
    - Never suggest weakening assertions to go green.
    - Fix root cause or explicitly align contract expectations.

EVIDENCE REQUIRED (when TARGETS is empty):
  - Ask the user to paste outputs (do not run unless allowed):
      git fetch --all --prune
      git checkout <PR_BRANCH>            (only if PR_BRANCH provided and CHECKOUT=ask)
      git diff <BASE_BRANCH>...HEAD --name-only
      git diff <BASE_BRANCH>...HEAD
  - If PR_BRANCH is provided but user cannot checkout, accept:
      git diff <BASE_BRANCH>...<PR_BRANCH> --name-only
      git diff <BASE_BRANCH>...<PR_BRANCH>

SEVERITY TO OUTCOME:
  - REQUEST_CHANGES: any MUST exists.
  - COMMENT: no MUST, but at least one SHOULD or any open Questions.
  - APPROVE: only NITS or no findings, and tests are acceptable (or clearly marked Not provided).

REFERENCING CODE:
  - Prefer file:line when available from diff evidence.
  - If line numbers are not available, use file + module/function as locator.
  - Do not paste large code blocks. Keep evidence short.

SLUG:
  - pr-<pr_branch_or_current>-to-<base_branch>-<YYYYMMDD> (kebab)
  - If PR_BRANCH missing, use current branch name if known; otherwise "pr"
  - If the file for the slug already exists, update it instead of creating a new one

OUTPUT:
  - Always output PLAN then unified diff for docs/reviews/<slug>.md only.
  - No commentary outside the report.

PLAN FORMAT (tight):
  - Goal:
  - Mode (targets|git diff):
  - Branches (pr/base):
  - Scope (files):
  - Context:
  - Output file:

NEEDS (no diff):
  - When TARGETS is empty and diff evidence is not provided:
    - Ask for the exact git outputs listed under EVIDENCE REQUIRED and (if relevant) the current branch name:
        git rev-parse --abbrev-ref HEAD

POST (ask mode):
  - Prompt user to run quality gates:
      mix format && mix compile --warnings-as-errors && mix credo --strict
      mix test

REPORT TEMPLATE (tight; GH-style):
# PR Review: <PR_BRANCH or current> -> <BASE_BRANCH> (<YYYY-MM-DD>)
## Summary
- Overall: APPROVE|REQUEST_CHANGES|COMMENT
- Key risks:
## Scope
- Files:
- Context:
## Blocking (MUST)
- <comment> | <file:line or file + fn> | Risk:<...> | Evidence:<...> | Fix:<...>
## Suggestions (SHOULD)
- <comment> | <file:line or file + fn> | Risk:<...> | Evidence:<...> | Fix:<...>
## Nits
- <comment> | <file:line or file + fn> | Fix:<...>
## Focus checks
- Contracts/Errors:
- Async/Oban:
- Queries/DB:
- Docs:
- Logs:
- Tests:
## Questions
- ...

EX:
  /review-pr PR_BRANCH="feature/pipeline-batch" BASE_BRANCH=main CHECKOUT=ask
  /review-pr BASE_BRANCH=main TARGETS="lib/elder/pipeline/**.ex test/elder/pipeline/**.exs"
