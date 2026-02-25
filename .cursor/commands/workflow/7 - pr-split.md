---
description: "Analyze local changes and propose how to split them into independent PRs -> docs/reviews/pr-split-<slug>.md"
---

IN:
  BASE=<branch>(default dev);
  FEATURE=<optional name>;
  CTX=<optional notes about intent, what goes together>;

SAFETY:
  - Read-only commands (git status, diff, log, fetch) can be run directly without asking.
  - Write/destructive commands must present the exact command and wait for user approval.
  - If the user declines a step, skip it and move to the next.

RULES:
  - Read-only analysis. Do not change any source code.
  - Only create/update docs/reviews/pr-split-<slug>.md.
  - Always output PLAN then unified diff. No extra commentary outside contract.
  - No emojis. No fluff.
  - If information is missing, write "Unknown" and move on.

GATHER (terminal mode):
  - Ask to run (single batch, all read-only):
      git status && git diff --name-status BASE...HEAD && git diff --name-only --cached && git log --no-merges --oneline BASE...HEAD
    - Fallback if BASE not found locally: replace BASE with origin/BASE
    - If BASE not reachable at all, ask user to provide file list manually.
  - After batch, read diff internally (do not dump into output):
      git diff BASE...HEAD

GATHER (non-terminal mode):
  - Ask user to paste outputs of the commands above.
  - If insufficient, output NEEDS listing exactly what is required.

ANALYSIS:
  - Group changes by concern using these signals (priority order):
    1) Functional coupling: files that call each other, share types, or break if separated.
    2) Domain boundary: files in the same context/module namespace.
    3) Change type: pure deletions, pure additions, refactors, tests, docs.
    4) Commit subjects: commits mentioning the same topic cluster together.
  - Detect file overlaps: if a file appears in multiple groups, flag it and
    propose which PR owns it (or if it needs to be split across commits).
  - Determine merge order:
    - If no file overlap and no caller/callee dependency between PRs: "independent, any order".
    - If PR A removes code that PR B stops calling: PR B first, then PR A.
    - If overlap exists: note it explicitly.

SPLIT CONSTRAINTS:
  - Each PR should be independently mergeable (compiles, tests pass on its own).
  - Prefer fewer PRs (2-3) over many small ones, unless concerns are truly disjoint.
  - Keep tests with the code they cover in the same PR.
  - Keep docs with the feature they document in the same PR.
  - Deletions of dead code should be their own PR when possible.

SLUG:
  - pr-split-<branch-or-feature>-<YYYYMMDD> (kebab).
  - If branch/feature unknown, use pr-split-local.
  - If the file already exists, update it.

OUTPUT:
  - PLAN (3-8 bullets, max ~600 chars) then unified diff for docs/reviews/pr-split-<slug>.md only.

PLAN FORMAT (tight):
  - Goal:
  - Base branch:
  - Total files changed:
  - Proposed split (count + names):
  - Overlap/dependency:
  - Output file:

MARKDOWN FORMAT:
# PR split plan — <FEATURE or branch>

<1-2 line summary: how many PRs, independent or ordered, why this split>

---

## PR <N> — <short title>

**Branch:** `<type>/<kebab-name>` from `<BASE>`

| Action | File |
|---|---|
| <M/A/D> | `<relative path>` |

**What it does:**
- <2-5 bullets: what changed + why>

**PR command context:**
```
/pr BASE=<BASE> FLOW=full CONTEXT="<ready-to-paste context string for the /pr command>"
```

---

(repeat per PR)

## Merge order
- <ordering guidance or "Independent — any order">
- <dependency notes if any>

LEARNINGS (self-improvement cycle):
  - Before running, read and respect ALL bullets below.
  - After running, if the output required manual fixes or missed something,
    append ONE concise bullet: - <what went wrong> -> <how to avoid it>
  - Keep each bullet to 1 line. No refactors to the command itself.

EX:
  /pr-split BASE=dev FEATURE="Pipeline refactor"
  /pr-split BASE=dev CTX="Goal: separate transform logic from IO adapters"
