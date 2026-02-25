---
description: "Stage, commit, push & create a GitHub PR (compact; why+how; from last N non-merge commits + diff)"
---

IN:
  BASE=<branch>(default dev);
  COMMITS=<N>(default 20);
  CONTEXT=<optional notes, tests run, rollout notes>;
  FLOW=<full|pr-only>(default full);
  PLAN=<optional path to docs/reviews/pr-split-*.md>;

SAFETY:
  - Run all commands directly. Cursor gatekeeps command execution via its own approval flow.
  - Never hardcode secrets or tokens.

PLAN INPUT (when PLAN is provided):
  - Read the split plan file and find the PR section matching the current branch or CONTEXT.
  - Use it as additional evidence: file list, branch name, "What it does" summary, and merge order.
  - The plan's "PR command context" block can be used directly as CONTEXT if none was provided.
  - PLAN supplements but does not override explicit IN parameters.

GIT FLOW (runs when FLOW=full, before PR description generation):
  Step 1 — Status:
    - Run: git status
    - Show output to user.

  Step 2 — Stage:
    - From the status output, present the list of changed/untracked files.
    - Exclude workflow-generated files from staging: docs/reviews/*, docs/features/*.
      If the user explicitly asks to include them, allow it.
    - Stage files accordingly via git add.
    - Run: git status (to confirm staged files).

  Step 3 — Commit:
    - Analyze the staged changes (diff --cached) to understand what changed.
    - Propose a commit message following this format:
        <type>: <concise summary>
      Types: feat, fix, refactor, test, docs, chore, perf
    - If the staged changes cover multiple concerns, propose splitting into
      multiple commits. Repeat Step 2+3 for each commit.
    - Run the git commit command with the proposed message.

  Step 4 — Push:
    - Detect current branch: git rev-parse --abbrev-ref HEAD
    - Check if remote tracking exists: git status -sb
    - Run: git push -u origin <branch> (or git push if tracking exists).

  Step 5 — PR:
    - Create PR via: gh pr create --base BASE --assignee @me
    - Always assign to current user via --assignee @me.

  After GIT FLOW completes (or if FLOW=pr-only), proceed to PR DESCRIPTION.

PR DESCRIPTION:

RULES:
  - The PR description is passed directly to `gh pr create --body`.
  - No docs/prs/*.md files are created. The PR body IS the output.
  - No emojis. No imperative tone. No fluff.
  - Source of truth (in priority order):
    1) git diff BASE..HEAD + last COMMITS non-merge commit subjects in BASE..HEAD
    2) user-provided CONTEXT
    3) PLAN file (if provided)
    4) currently open diffs (if present)
  - Ignore merge commits.
  - Do not guess. If information is missing, write:
      "Not provided" / "Not run (not provided)" / "Unknown"
    briefly and move on.
  - No big code blocks. No snippets unless unavoidable:
      max 1 snippet, <= 10 lines.
  - Do not run tests or quality gates automatically. Only report what was already run and provided (via CONTEXT or observable evidence).

TERMINAL MODE:
  - Run directly:
      git fetch --all --prune && git diff --name-status BASE..HEAD && git log --no-merges --pretty=format:%s BASE..HEAD | tail -n COMMITS
    - If BASE not found locally, try origin/BASE..HEAD as fallback
  - After batch, read diff internally (do not quote in PR text):
      git diff BASE..HEAD

AREA CLASSIFICATION (by paths):
  - BE:
      lib/**,
      test/** (when BE tests)
  - DB:
      priv/repo/**,
      **/migrations/**
  - Obs:
      logging, telemetry, tracing, metrics, instrumenters (by file path or commit subject)
  - Tests:
      test/**

KEY NAMES (modules/functions) POLICY:
  - Prefer file paths for specificity.
  - Mention module/function names only if explicitly visible in commit subjects or clearly present in diffs.
  - If uncertain, omit names rather than guessing.

RISK FLAGS (evidence-based only):
  - BC:
      yes only if public API surface clearly changed (public function return shape/spec, config contract).
      otherwise no/unknown.
  - DB:
      yes only if migrations/backfills/locking changes exist in diff.
  - Async:
      yes only if Oban workers, job args, uniqueness/idempotency, queue behavior changed.
  - Perf:
      yes only if query shape/loops/batching/concurrency boundaries changed.

PR BODY FORMAT:
## Summary
- 2–5 bullets: what changed + why (user/ops impact)

## Changes
- BE:
- DB:
- Obs:
- Tests:
  - Omit empty sections
  - Bullets per area; prefer file paths; mention key modules only when certain

## Tests
- <what ran + result> or "Not run (not provided)"

## Risk / Rollout
- BC: <yes/no/unknown> — <1 line why>
- DB: <yes/no/unknown> — <migrations/backfill/locks note>
- Async: <yes/no/unknown> — <idempotency/retry/side-effects note>
- Perf: <yes/no/unknown> — <hotspots note>

## Observability
- <logs/metrics/traces changes> or "None/Not provided"

OUTPUT:
  - The PR body is passed directly to `gh pr create --body` using a HEREDOC.
  - No markdown files are created. No docs/prs/ directory is used.

LEARNINGS (self-improvement cycle):
  - Before running, read and respect ALL bullets below.
  - After running, if the output required manual fixes or missed something,
    append ONE concise bullet: - <what went wrong> -> <how to avoid it>
  - Keep each bullet to 1 line. No refactors to the command itself.

EX:
  /pr BASE=dev COMMITS=15 CONTEXT="Goal: batch processing; Notes: adds uniqueness to job enqueue; Ran: mix test test/elder/pipeline_test.exs"
  /pr BASE=dev FLOW=full CONTEXT="Goal: batch processing"
  /pr BASE=dev FLOW=pr-only COMMITS=10
  /pr BASE=dev PLAN="docs/reviews/pr-split-pipeline-refactor-20260224.md"
