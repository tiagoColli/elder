---
description: "Debug an issue (repro->root cause->minimal fix plan; optional patch) -> docs/reviews/<slug>.md"
---
IN:ISSUE=<brief>;SIGNAL=<error/log/test>;TARGETS=<opt file list|glob>;CONTEXT=<opt notes>;MODE=report|plan+patch(def report)
RULES:-Primary goal: find root cause with evidence; avoid guessy patches.-Prefer evidence sources in order: failing test > deterministic repro > logs/traces > code inspection.-If TARGETS missing: use git to discover changed files (staged+unstaged), else derive likely scope from SIGNAL.-No behavior change unless MODE=plan+patch; MODE=report writes report only.-No inline comments in code(no #, no /* */).-Be strict about contracts: identify where shape breaks, nil leaks, match errors, race conditions, retries/idempotency issues, query explosions, timeouts.-Async: check Task usage for bounded concurrency/timeouts; check Oban job args/idempotency/uniqueness/queue fit; check retry storms.-Queries: check N+1, Repo calls in loops, missing preloads, "fetch-all then filter", missing indexes hints if obvious, long transactions.-Output must be actionable: suspected root cause, file/line pointers, fix options, and verification steps; no fluff.
DO(terminal if allowed; ask mode):-Identify scope: git diff --name-only / --cached; git status --porcelain.-If SIGNAL is test: run targeted mix test <file>:<line> to confirm; capture first failure.-If SIGNAL is log/exception: locate origin; find failing pattern match/raise; trace call chain to entrypoint.-If SIGNAL is runtime behavior: outline minimal repro (inputs, steps) and expected vs actual.
OUT:-MODE=report => unified diff touching ONLY docs/reviews/<slug>.md.-MODE=plan+patch => PLAN(max 10 bullets) + unified diff for fix (code only) AND update docs/reviews/<slug>.md in same patch.
SLUG:debug-<kebab(issue_or_signal)>-<YYYYMMDD>
REPORT template(tight):
# Debug: <ISSUE> (<YYYY-MM-DD>)
## Signal
-What happened:
-Evidence:
## Scope
-Files:
-Entry point:
## Hypothesis
-Root cause:
-Why likely:
## Findings
-MUST:
-SHOULD:
## Fix options
-Option A(minimal):
-Option B(if needed):
## Verification
-Commands:
-Expected:
POST(ask mode):Prompt user to run quality gates: mix format && mix compile --warnings-as-errors && mix credo --strict; plus targeted mix test for affected area.

EX: /debug ISSUE="MatchError in pipeline transform" SIGNAL="test/elder/pipeline_test.exs:42" MODE=report
