# Elder.Chat.Session — Chat State Machine Design

Date: 2026-04-10
Status: Draft
Area: Foundation / Infrastructure
Depends on: `Elder.Chat.Conversation` (2026-04-10-chat-conversation-design.md)

## Problem

`SkillRunLive` owns all chat orchestration: PubSub subscription, LLM calls,
response parsing, conversation state updates, error handling, and phase
transitions. This is ~200 lines of `handle_info` + private helpers that any
second chat-powered skill would need to duplicate.

`Elder.Chat.Conversation` solved the data structure problem — message history,
turn tracking, status, formatting. But the **flow** (send message → call LLM →
receive response → parse → continue or finish) still lives in the LiveView.

## Goal

Build `Elder.Chat.Session` — a functional orchestration module that manages
a chat session lifecycle. It wraps `Conversation`, coordinates with `Elder.LLM`,
and provides a simple API (`start`, `continue`, `handle_response`, `finish`)
that LiveViews use to run chat-powered features without touching LLM wiring.

This is the second foundation layer: `Conversation` owns data, `Session` owns flow.

## Non-Goals

- No GenServer or per-session process (LiveView holds the session in assigns)
- No PubSub (replaced with direct `send/2` via supervised tasks)
- No retry logic (errors propagate to the caller, LiveView decides UX)
- No post-chat orchestration (streaming, structured output, Asana — stays in LiveView)
- No agent workflows or multi-step pipelines (future concern)

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Process model | Pure functional, no GenServer | LiveView is already a process holding state; a GenServer per chat is a middleman |
| Async delivery | `send/2` from supervised task | Chat sessions are 1:1 (one LiveView, one LLM call); PubSub's 1:N fanout is unused overhead |
| LLM integration | Through `Elder.LLM` facade | Session calls the facade, facade spawns task under `TaskSupervisor`, task sends result to caller |
| Response parsing | Callback function per skill | `response_handler` is a function provided at session creation; keeps skill-specific parsing out of the session module |
| Error handling | Simple propagation | Session records the error and transitions to `:failed`; no retries, no formatting — caller decides |
| State location | LiveView assigns | `assign(socket, session: %Session{})` — same pattern as `chat: %Conversation{}` today |

---

## Data Structure

### `Elder.Chat.Session`

The session struct wraps a `Conversation` and adds orchestration state.

```elixir
defmodule Elder.Chat.Session do
  alias Elder.Chat.Conversation

  @type status :: :awaiting_llm | :awaiting_user | :completed | :failed

  @type continue_data :: %{
    text: String.t(),
    question: String.t() | nil,
    suggestions: [Elder.Chat.Message.suggestion()],
    artifacts: [struct()]
  }

  @type handler_result ::
    {:continue, continue_data()}
    | {:ready, %{artifacts: [struct()]}}
    | {:error, term()}

  @type response_handler :: (String.t() -> handler_result())

  @type t :: %__MODULE__{
    id: String.t(),
    conversation: Conversation.t(),
    status: status(),
    review_skill: map(),
    caller: pid(),
    response_handler: response_handler(),
    error: term() | nil
  }

  @enforce_keys [:id, :conversation, :review_skill, :caller, :response_handler]
  defstruct [
    :id,
    :conversation,
    :review_skill,
    :caller,
    :response_handler,
    :error,
    status: :awaiting_llm
  ]
end
```

Status transitions:
- `start/4` creates session with `:awaiting_llm`
- `:awaiting_llm` → `handle_response/2` → `:awaiting_user` (both `:continue` and `:ready` signals)
- `:awaiting_user` → `continue/2` → `:awaiting_llm`
- `:awaiting_user` → `finish/1` → `:completed`
- Any state → `handle_error/2` → `:failed`

`handle_response` returning `:ready` does NOT transition to `:completed` — it
stays at `:awaiting_user` so the LiveView can still `continue` if validation
fails (e.g., missing required fields). Only `finish/1` transitions to `:completed`.

No transition back from `:failed` — the LiveView starts a new session if needed.

---

## Public API

All functions update internal state. `start/4` and `continue/2` also trigger
an LLM call through the `Elder.LLM` facade.

### `start/4`

Creates the session, adds the user's initial message, fires the first LLM call.

```elixir
ChatSession.start(review_skill, user_prompt, response_handler, caller: self())
# => {:ok, %Session{status: :awaiting_llm}}
```

Internally:
1. Creates a `Conversation` via `Conversation.new/1`
2. Adds the user message via `Conversation.add_user_message/2`
3. Builds LLM message list via `Conversation.to_llm_messages/1`
4. Calls `LLM.interview_run(review_skill, messages, caller: caller)`
5. Returns the session with `status: :awaiting_llm`

### `continue/2`

Adds the user's reply and fires the next LLM call.

```elixir
ChatSession.continue(session, user_text)
# => {:ok, %Session{status: :awaiting_llm}}
```

Guards: returns `{:error, :not_awaiting_user}` if status is not `:awaiting_user`.

Internally:
1. Adds user message to conversation (increments turn count)
2. Calls `LLM.interview_run` with updated message list
3. Returns session with `status: :awaiting_llm`

### `handle_response/2`

Receives raw LLM text, runs the response handler callback, updates the conversation.

```elixir
ChatSession.handle_response(session, raw_text)
# => {:ok, %Session{status: :awaiting_user}, :continue}
# => {:ok, %Session{status: :awaiting_user}, :ready}
# => {:error, %Session{status: :failed}, reason}
```

Internally:
1. Calls `session.response_handler.(raw_text)`
2. On `{:continue, data}`: adds assistant message with question/suggestions/artifacts,
   sets status to `:awaiting_user`
3. On `{:ready, data}`: adds assistant message with artifacts,
   sets status to `:awaiting_user` (NOT `:completed` — the caller decides
   whether to `finish/1` or `continue/2` after validation)
4. On `{:error, reason}`: delegates to `handle_error/2`, returns `{:error, session, reason}`

### `handle_error/2`

Records an error and transitions to `:failed`.

```elixir
ChatSession.handle_error(session, reason)
# => {:ok, %Session{status: :failed, error: reason}}
```

Marks the conversation as failed via `Conversation.fail/1`. Stores the reason
on `session.error`. One path for all errors — LLM failures and parse failures
both end up here.

### `finish/1`

Completes the conversation and returns the transcript.

```elixir
ChatSession.finish(session)
# => {:ok, %Session{status: :completed}, transcript}
```

Calls `Conversation.complete/1` and `Conversation.to_transcript/1`. Separate
from `handle_response` because the LiveView may need to validate between
receiving `:ready` and actually finishing (e.g., `required_interview_fields_present?`).

### Query helpers

```elixir
ChatSession.messages(session)         # => [%Message{}, ...]
ChatSession.conversation(session)     # => %Conversation{}
ChatSession.awaiting_user?(session)   # => true | false
```

---

## Response Handler System

### Contract

The response handler is a plain function — no behaviour module. It receives raw
LLM text and returns a standardized result.

```elixir
@type response_handler :: (String.t() -> handler_result())
```

The session module never imports or knows about skill-specific parsers or
artifact types. The handler encapsulates all of that.

### Asana Implementation

Lives at `Elder.Asana.ResponseHandler` (inside the Asana connector, not inside
`Elder.Chat`). Wraps the existing `InterviewResponse.parse/1`:

```elixir
defmodule Elder.Asana.ResponseHandler do
  alias Elder.Asana.Artifacts.Draft, as: AsanaDraft
  alias Elder.LLM.InterviewResponse
  alias Elder.LLM.InterviewResponseDraft

  @spec handle(String.t()) :: Elder.Chat.Session.handler_result()
  def handle(raw_text) do
    if String.trim(raw_text) == "[READY]" do
      {:ready, %{artifacts: []}}
    else
      case InterviewResponse.parse(raw_text) do
        {:ok, %{status: :continue} = p} ->
          {:continue, %{
            text: p.assistant_message,
            question: p.question,
            suggestions: p.suggestions,
            artifacts: [build_draft(p.draft)]
          }}

        {:ok, %{status: :ready} = p} ->
          {:ready, %{artifacts: [build_draft(p.draft)]}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp build_draft(%InterviewResponseDraft{} = d) do
    %AsanaDraft{
      name: d.name,
      description: d.description,
      responsible_email: d.responsible_email,
      due_on: d.due_on,
      skipped_fields: d.skipped_fields
    }
  end
end
```

Dependency direction:
```
Elder.Asana.ResponseHandler --> Elder.LLM.InterviewResponse (parser)
Elder.Asana.ResponseHandler --> Elder.Asana.Artifacts.Draft (artifact)
Elder.Chat.Session          --> response_handler function (injected)
Elder.Chat.Session          -/-> Elder.Asana (no reverse dependency)
```

### Adding Future Response Handlers

A future skill provides its own handler:

1. Create `Elder.Email.ResponseHandler` with a `handle/1` function
2. Parse the LLM text however that skill needs
3. Return `{:continue, data}` or `{:ready, data}` or `{:error, reason}`
4. Pass `&Elder.Email.ResponseHandler.handle/1` to `ChatSession.start/4`

No changes to `Elder.Chat.Session`.

---

## LLM Facade Changes

### Current interface (PubSub)

```elixir
LLM.interview_run(review_skill, messages, pubsub_topic)
# Client broadcasts: PubSub.broadcast(Elder.PubSub, topic, {:interview_done, result})
```

### New interface (direct send)

```elixir
LLM.interview_run(review_skill, messages, caller: pid)
# Client sends: send(caller, {:interview_done, result})
```

The third argument changes from a topic string to a keyword list with `:caller`.
Internally, `Elder.LLM.Client` spawns the task under `Elder.LLM.TaskSupervisor`
as before — the only change is delivery: `send/2` instead of `PubSub.broadcast/3`.

The same change applies to `stream_run/3` and `structured_run/5`. These aren't
used by the session module but should be consistent. The old PubSub
subscribe/unsubscribe code in `SkillRunLive` gets deleted.

Message shapes stay the same:
- Interview: `{:interview_done, {:ok, text}}` | `{:interview_done, {:error, reason}}`
- Streaming: `:llm_token`, `:llm_done`, `:llm_error`
- Structured: `{:llm_object_done, {:ok, data}}` | `{:llm_object_done, {:error, reason}}`

The `Elder.LLM.ClientBehaviour` callbacks change their last parameter from
`pubsub_topic :: String.t()` to `opts :: keyword()` with `:caller`.

---

## Integration: SkillRunLive Migration

### Assigns Change

Before:
```elixir
assign(socket, chat: nil, chat_loading: false)
```

After:
```elixir
assign(socket, session: nil, chat_loading: false)
```

### Flow Mapping

**Starting the interview:**

```elixir
{review_skill, _format} ->
  {:ok, session} = ChatSession.start(
    socket.assigns.review_skill,
    input,
    &Elder.Asana.ResponseHandler.handle/1,
    caller: self()
  )

  {:noreply, assign(socket, phase: :chatting, session: session, chat_loading: true)}
```

**Receiving LLM response:**

```elixir
def handle_info({:interview_done, {:ok, text}}, socket) do
  case ChatSession.handle_response(socket.assigns.session, text) do
    {:ok, session, :continue} ->
      {:noreply, assign(socket, session: session, chat_loading: false, error: nil)}

    {:ok, session, :ready} ->
      case socket.assigns.skill.output_format do
        :structured_asana_task ->
          if required_interview_fields_present?(session) do
            {:noreply, interview_finish_to_structured(socket, session)}
          else
            {:noreply, inject_required_fields_error(socket, session)}
          end
        _other ->
          {:noreply, interview_finish_to_streaming(socket, session)}
      end

    {:error, session, _reason} ->
      {:noreply, assign(socket, session: session, chat_loading: false,
        error: "The assistant reply could not be read. Please try again.")}
  end
end

def handle_info({:interview_done, {:error, reason}}, socket) do
  {:ok, session} = ChatSession.handle_error(socket.assigns.session, reason)
  {:noreply, assign(socket, session: session, chat_loading: false,
    error: format_llm_error(reason))}
end
```

**User replies:**

```elixir
def handle_event("chat_reply", %{"message" => message}, socket) do
  {:ok, session} = ChatSession.continue(socket.assigns.session, message)
  {:noreply, assign(socket, session: session, chat_loading: true, error: nil)}
end
```

### Code Removed from SkillRunLive

| Function | Destination |
|----------|-------------|
| `interview_user_message/2` | `ChatSession.continue/2` |
| `build_asana_draft/1` | `Elder.Asana.ResponseHandler.build_draft/1` |
| PubSub subscribe/unsubscribe | Deleted (no longer needed) |
| Interview parsing in `handle_info` | `ChatSession.handle_response/2` + response handler |

### Code Stays in LiveView

- Phase transitions beyond chat (`:streaming`, `:processing`, `:previewing`, etc.)
- `required_interview_fields_present?/1` and `inject_required_fields_error/2`
- Template rendering (uses `ChatSession.messages(session)`)
- Error message formatting (UI concern)
- Post-chat LLM calls (`stream_run`, `structured_run`) — these use the updated
  facade directly, not through the session

---

## File Structure

```
lib/elder/chat/
├── artifact.ex              # Elder.Chat.Artifact (existing)
├── conversation.ex          # Elder.Chat.Conversation (existing)
├── message.ex               # Elder.Chat.Message (existing)
└── session.ex               # Elder.Chat.Session (new)

lib/elder/connectors/asana/
├── artifacts/
│   └── draft.ex             # Elder.Asana.Artifacts.Draft (existing)
└── response_handler.ex      # Elder.Asana.ResponseHandler (new)

lib/elder/llm.ex             # Elder.LLM (modified — caller instead of pubsub_topic)
lib/elder/llm/client/
├── behaviour.ex             # Elder.LLM.ClientBehaviour (modified)
└── client.ex                # Elder.LLM.Client (modified — send instead of broadcast)
```

## Testing Strategy

### Session Unit Tests

Mock the LLM client (existing behaviour + Mox). Inject a test response handler.

- `start/4` — creates conversation, adds user message, calls LLM, status `:awaiting_llm`
- `continue/2` — adds user message, calls LLM, guards wrong status
- `handle_response/2` with `:continue` — adds assistant message, status `:awaiting_user`
- `handle_response/2` with `:ready` — status `:completed`
- `handle_response/2` with handler error — status `:failed`, error stored
- `handle_error/2` — records error, status `:failed`
- `finish/1` — completes conversation, returns transcript
- Full loop: start → response → continue → response → ready
- Status guards: `continue` when not `:awaiting_user`, `start` when already started

### Asana ResponseHandler Tests

No session, no mocks — pure parsing tests.

- Valid continue response → `{:continue, data}` with `AsanaDraft` artifact
- Valid ready response → `{:ready, data}` with `AsanaDraft` artifact
- Bare `[READY]` text → `{:ready, %{artifacts: []}}`
- Invalid JSON → `{:error, :invalid_interview_json}`
- Invalid status → `{:error, :invalid_interview_status}`

### LLM Facade Tests

- `interview_run/3` with `caller:` option sends result to caller PID
- `stream_run/3` with `caller:` option delivers tokens to caller PID
- `structured_run/5` with `caller:` option sends object to caller PID

---

## Future Extensions (not built now)

- **Session recovery:** `recover/1` to reset a failed session to `:awaiting_user`
  so the user can retry without losing conversation history.
- **Timeout handling:** `Process.monitor` on task refs or timer-based timeout
  detection when the LLM task doesn't respond.
- **Token/cost tracking:** accumulate LLM cost per session for billing/analytics.
- **Session persistence:** serialize/deserialize a session for resume-after-reconnect.
- **Multi-consumer observation:** if needed later, re-add PubSub as an opt-in
  delivery mechanism alongside `send/2`.
