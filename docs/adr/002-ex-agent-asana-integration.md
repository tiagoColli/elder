# ADR-002: ExAgent for Asana task creation

**Date**: 2026-04-17
**Status**: Accepted

## Context and Problem Statement

The skill-run flow needs to create Asana tasks from interview drafts. The previous
approach used a single `Elder.Asana.create_task/2` call from the LiveView, handling
assignment and tagging as separate imperative steps. As the number of post-creation
actions grew (assign user, add tags, set custom fields), the LiveView accumulated
orchestration logic that belongs closer to the domain.

We needed a way for an LLM to decide which Asana operations to perform and in what
order, based on the draft context, without hard-coding the sequence in the LiveView.

## Decision Drivers

* Keep LiveView thin — orchestration belongs in the domain layer
* Allow the LLM to reason about which tools to call (create → assign → tag)
* Reuse ExLLM infrastructure already in the project for chat calls
* Maintain testability via Mox — the agent should be fully testable without real API calls

## Considered Options

1. **Imperative orchestration in Interview/LiveView** — sequential if-then calls
2. **ExAgent with tool loop** — LLM-driven tool execution via `ex_agent` library
3. **Custom GenServer agent** — hand-rolled tool loop without a library

## Decision Outcome

Chosen option: **"ExAgent with tool loop"**, because it provides a tested agent
framework with tool registration, message history, and a clean protocol boundary
(`ExAgent.LlmProvider`) that we bridge to ExLLM via `Elder.ExAgent.ExLLMProvider`.

### Positive Consequences

* LiveView delegates to `Interview.execute/2` → `AsanaAgent.run/3` — no tool logic in the web layer
* Adding new Asana tools (e.g. `set_custom_field`) requires only a new tool module
* PubSub progress broadcasts let the LiveView show real-time agent status
* Full test coverage via `ExLLM.Providers.Mock` + `Mox` for the Asana client

### Negative Consequences

* New dependency: `ex_agent` — adds to the dependency tree
* Ephemeral GenServer per execution — short-lived process created and stopped per task creation
* LLM cost per execution — each agent run involves 2–3 LLM calls (tool calls + final summary)

## Links

* `lib/elder/ex_agent/asana_agent.ex` — Agent orchestrator
* `lib/elder/ex_agent/exllm_provider.ex` — ExLLM ↔ ExAgent bridge
* `lib/elder/ex_agent/tools/` — Tool modules (create_task, assign_user, add_tags)
* `lib/elder/interview.ex` — `execute/2` entry point
