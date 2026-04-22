# ADR-001: Replace ReqLLM + Chat layer with ExLLM

**Date**: 2026-04-17
**Status**: Accepted

## Context and Problem Statement

The LLM integration was spread across three abstraction layers: `ReqLLM` as the
HTTP client, `Elder.LLM.Client` / `Elder.LLM.ClientBehaviour` as a mockable
adapter, and `Elder.Chat.*` (Conversation, Message, Session, Artifact) as a
hand-rolled multi-turn conversation manager. The Chat layer alone totalled ~600
lines of pure-functional state management (turn counting, message ordering,
artifact serialization, transcript formatting) that duplicated features already
provided by libraries like ExLLM (session management, structured output,
streaming, provider abstraction).

Adding new interview features (e.g. sliding-window context, response schemas)
required touching three layers per change, and the `ClientBehaviour` Mox seam
masked real provider behaviour in tests.

## Decision Drivers

* Reduce indirection — three layers (ReqLLM → Client → Chat.Session) for one LLM call is excessive
* Leverage ExLLM's built-in session, structured output (`response_model`), and streaming support
* Simplify testing — ExLLM's mock provider replaces the `ClientBehaviour` Mox seam for interview tests
* Keep the Asana client Mox boundary (HTTP integration) separate from LLM testing concerns

## Considered Options

1. **Keep ReqLLM + Chat layer, add features incrementally** — extend existing abstractions
2. **Replace ReqLLM with ExLLM, keep Chat layer** — swap only the HTTP client
3. **Replace ReqLLM with ExLLM, delete Chat layer entirely** — use ExLLM sessions as the conversation primitive

## Decision Outcome

Chosen option: **"Replace ReqLLM with ExLLM, delete Chat layer entirely"**,
because ExLLM's `Session` type provides conversation history, message management,
and transcript access that made the hand-rolled Chat.Conversation/Message/Session
redundant.

### What Changed

| Removed | Replaced By |
|---------|-------------|
| `req_llm` dependency | `ex_llm ~> 0.8` |
| `Elder.LLM.Client` + `ClientBehaviour` | Direct `ExLLM.chat/3` and `ExLLM.stream_chat/3` calls inside `Elder.LLM` |
| `Elder.LLM.ContextBuilder` | Inline message-list construction in `Elder.LLM` |
| `Elder.LLM.InterviewResponse` (manual JSON parsing) | `Elder.Schemas.InterviewResponse` with `ExLLM` `response_model` |
| `Elder.Chat.Conversation` | `ExLLM.Types.Session` (via `ExLLM.new_session/2`) |
| `Elder.Chat.Message` | Plain message maps (`%{role: "user", content: "..."}`) |
| `Elder.Chat.Session` | `Elder.Interview` — thin orchestrator holding an `ExLLM.Types.Session` |
| `Elder.Chat.Artifact` behaviour | Removed; `Draft.to_transcript/1` keeps its `@spec` without the behaviour |
| `Elder.Asana.ResponseHandler` | Parsing moved into `Elder.Interview.handle_response/2` via `InterviewResponse` struct |

### Positive Consequences

* Net deletion: **−1,116 lines** (2,575 removed, 1,459 added) — less surface area to maintain
* `Elder.Interview` is a single-file orchestrator (~340 lines) replacing four Chat modules + Session
* Interview tests use `ExLLM.Providers.Mock` with `dispatch_enabled: false` — no Mox for LLM, Mox stays only for Asana HTTP
* Structured output via `response_model: InterviewResponse` eliminates manual JSON parsing + retry logic
* Sliding-window context management (`strategy: :sliding_window`) is a one-line config instead of custom implementation
* `Elder.LLM` shrank from routing layer to two public functions (`stream_run`, `structured_run`) with inline task dispatch

### Negative Consequences

* New dependency: `ex_llm ~> 0.8` — replaces `req_llm ~> 1.9` (net-zero dependency count)
* Env var bridge: `GOOGLE_API_KEY` → `GEMINI_API_KEY` shim in `runtime.exs` until deployments are updated
* `Elder.Interview` owns both session state and LLM dispatch — tighter coupling than the previous Session/Client split, acceptable given the module's small size

## Links

* `lib/elder/interview.ex` — Interview orchestrator (replaces Chat.Session)
* `lib/elder/llm.ex` — Streaming and structured generation (replaces LLM.Client)
* `lib/elder/schemas/interview_response.ex` — Structured response schema (replaces LLM.InterviewResponse)
* `lib/elder_web/live/skill_run_live.ex` — LiveView wiring updated for new message shapes
