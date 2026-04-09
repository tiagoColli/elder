# Asana Review Structured Discovery Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fazer o fluxo de entrevista (`create-asana-task-review`) responder em JSON estruturado a cada turno, com rascunho dos quatro campos, mensagem curta estilo “plano”, sugestões opcionais (0–3) quando útil, e `status: ready` no lugar exclusivo de `[READY]`; atualizar `SkillRunLive` para renderizar rascunho + chips e montar o transcript para a skill principal.

**Architecture:** O `Elder.LLM.Client` continua devolvendo texto bruto do provedor. Um módulo puro `Elder.LLM.InterviewResponse` faz extração de JSON (corpo puro ou cercado por markdown), decodifica com Jason e normaliza/valida o mapa. `SkillRunLive` interpreta `{:interview_done, {:ok, text}}` chamando esse módulo; mensagens de assistente na conversa passam a carregar `text` (bolha), `draft` e `suggestions`. Compatibilidade: ainda aceitar resposta exatamente `[READY]` por um turno, se o texto não for JSON válido (facilita rollout).

**Tech Stack:** Elixir ~> 1.18, Phoenix LiveView, Jason, ReqLLM (sem mudar contrato PubSub além do consumo no LiveView), testes ExUnit + `Phoenix.LiveViewTest`.

**Contexto de produto (brainstorm):** Opção **A** — a cada resposta do usuário, a IA atualiza o rascunho dos quatro campos e pode oferecer sugestões só quando pertinente; transcript estruturado + UI. Sugestões via clique **enviam** a mensagem como se o usuário tivesse digitado (menos fricção).

---

### Task 1: `InterviewResponse` — testes primeiro (JSON válido)

**Files:**
- Create: `test/elder/llm/interview_response_test.exs`
- Create: `lib/elder/llm/interview_response.ex` (stub vazio até o passo 3)

**Step 1: Write the failing test**

Em `test/elder/llm/interview_response_test.exs`:

```elixir
defmodule Elder.LLM.InterviewResponseTest do
  use ExUnit.Case, async: true

  alias Elder.LLM.InterviewResponse

  test "parse/1 decodes minimal continue payload" do
    json = ~S"""
    {"status":"continue","draft":{"title":null,"responsible":null,"description":null,"due_date":null},"assistant_message":"Olá","question":"Qual o título?"}
    """

    assert {:ok, parsed} = InterviewResponse.parse(json)
    assert parsed.status == :continue
    assert parsed.draft.title == nil
    assert parsed.assistant_message == "Olá"
    assert parsed.question == "Qual o título?"
    assert parsed.suggestions == []
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/elder/llm/interview_response_test.exs`

Expected: **FAIL** (module/function missing).

**Step 3: Implement minimal module**

Em `lib/elder/llm/interview_response.ex`, implementar `parse/1` que:
- Faz `Jason.decode/1`
- Exige chaves string `"status"`, `"draft"`, `"assistant_message"`
- `"status"` → `:continue` ou `:ready`
- `"draft"` → mapa com chaves `title`, `responsible`, `description`, `due_date` (valores string ou `null`)
- `"question"` opcional (default `nil`)
- `"suggestions"` opcional — lista de objetos `label` + `value` (strings), no máximo 3 entradas; se vier mais, truncar ou erro (escolha uma e documente no `@moduledoc`; recomendação: truncar e logar em dev apenas se quiser, YAGNI: truncar silenciosamente)

Retornar `{:ok, %InterviewResponse{...}}` usando struct `defstruct` ou mapa nomeado — **struct** facilita `@type` e dialyzer.

**Step 4: Run test to verify it passes**

Run: `mix test test/elder/llm/interview_response_test.exs`

Expected: **PASS**

---

### Task 2: `InterviewResponse` — JSON dentro de fence e lixo ao redor

**Files:**
- Modify: `test/elder/llm/interview_response_test.exs`
- Modify: `lib/elder/llm/interview_response.ex`

**Step 1: Write failing test**

```elixir
test "parse/1 extracts JSON from markdown fence" do
  raw = """
  Here is the JSON:

  ```json
  {"status":"ready","draft":{"title":"X","responsible":"Y","description":"Z","due_date":"2026-05-01"},"assistant_message":"Pronto."}
  ```
  """

  assert {:ok, parsed} = InterviewResponse.parse(raw)
  assert parsed.status == :ready
  assert parsed.draft.title == "X"
end
```

**Step 2: Run test — expect FAIL**

**Step 3: Implement extraction**

Antes de `Jason.decode`, tentar:
1. Se o texto contém ```json ... ```, usar o interior.
2. Senão, localizar primeiro `{` e último `}` e decodificar o substring (cuidado com strings JSON que contenham `}` — para YAGNI, aceitar que o modelo deve devolver um único objeto; documentar).

**Step 4: Run test — expect PASS**

---

### Task 3: `InterviewResponse` — erros e `ready` sem pergunta

**Files:**
- Modify: `test/elder/llm/interview_response_test.exs`
- Modify: `lib/elder/llm/interview_response.ex`

**Step 1: Add tests**

- String não-JSON → `{:error, :invalid_interview_json}` (ou atomo estável de sua escolha).
- `status` desconhecido → erro.
- Payload `ready` com `question` nil e `suggestions` vazias → OK.

**Step 2: Implement validation branches**

**Step 3:** `mix test test/elder/llm/interview_response_test.exs` — all PASS

---

### Task 4: Atualizar o skill de review (contrato JSON)

**Files:**
- Modify: `priv/skills/create-asana-task-review/skill.md`

**Step 1:** Substituir a seção **Signal** `[READY]` por instruções: resposta **somente** JSON (sem texto fora do objeto, idealmente) com schema:

- `status`: `"continue"` | `"ready"`
- `draft`: objeto com `title`, `responsible`, `description`, `due_date` (string ou `null`)
- `assistant_message`: string (tom amigável; pode incluir resumo “plano” do que já foi entendido)
- `question`: string ou omitido/`null` quando `status` é `ready` ou quando não há pergunta (se `continue`, preferir uma pergunta clara a menos que esteja só confirmando o rascunho numa única frase — alinhar regra: **no máximo uma pergunta por turno**)
- `suggestions`: array opcional, 0–3 itens `{ "label": "...", "value": "..." }` — preencher só com ambiguidade ou atalho útil; omitir se o brief já for inequívoco

**Step 2:** Manter tabela dos quatro campos e regras de não inventar dados; acrescentar parágrafo “Em todo turno, atualize `draft` com tudo que puder inferir da conversa.”

**Step 3:** Revisar manualmente o arquivo em preview (sem teste automatizado obrigatório).

---

### Task 5: `SkillRunLive` — interpretar JSON no `handle_info` e compat `[READY]`

**Files:**
- Modify: `lib/elder_web/live/skill_run_live.ex` (função `handle_info({:interview_done, {:ok, text}}, socket)`)
- Modify: `test/elder_web/live/skill_run_live_test.exs`

**Step 1: Write failing LiveView test**

Novo teste: com usuário autenticado, `live/2` em `~p"/skills/create-asana-task/run"`, submeter brief via `render_submit`, depois `send(view.pid, {:interview_done, {:ok, json_string}})` onde `json_string` é um `continue` com `assistant_message` e draft com título preenchido.

Asserções:
- HTML contém o `assistant_message`
- HTML contém o título do draft (ex.: em região “Draft” / data-testid)

*Nota:* até a UI existir, o teste pode falhar por não achar o draft — isso é esperado no RED.

**Step 2: Implement handle_info**

- `InterviewResponse.parse(text)`:
  - `{:ok, %{status: :ready}}` → mesmo fluxo atual de `[READY]` (transcript + `stream_run`).
  - `{:ok, %{status: :continue} = p}` → append `%{role: :assistant, text: p.assistant_message, draft: p.draft, suggestions: p.suggestions}` (valores default `[]`).
  - `{:error, _}` → se `String.trim(text) == "[READY]"`, tratar como ready; senão assign `error` amigável e `chat_loading: false`.

**Step 3: Adjust `build_transcript/1`**

Incluir para cada turno de assistente, além da mensagem, um bloco legível com os quatro campos do `draft` (só chaves não vazias), para a skill principal receber contexto rico. Exemplo:

```
Assistant: <assistant_message>
Draft — title: ... | responsible: ... | ...
```

Garantir que mensagens antigas só com `text` ainda funcionem (sem `draft`).

**Step 4: Run tests**

Run: `mix test test/elder_web/live/skill_run_live_test.exs`

Expected: **PASS**

---

### Task 6: UI — painel de rascunho e chips de sugestão

**Files:**
- Modify: `lib/elder_web/live/skill_run_live.ex` (`render/1` e `handle_event/3`)

**Step 1: Render**

Na fase `:chatting`, para cada mensagem `role == :assistant`:
- Bolha com `@msg.text` (como hoje).
- Se existir `draft` com algum campo não nil, bloco abaixo (estilo `bg-zinc-50`, texto `text-xs`) listando os quatro rótulos e valores ou “—”.
- Se `suggestions != []`, botões `phx-click="pick_suggestion"` com `phx-value-message` igual a `value` (ou `phx-value-*` conforme API LiveView).

**Step 2: `handle_event("pick_suggestion", %{"message" => message}, socket)`**

Reutilizar a mesma lógica de `chat_reply`: anexar user turn, `interview_run`, `chat_loading: true`.

**Step 3: Teste LiveView**

Estender teste: JSON com `suggestions`; render deve mostrar `label`; simular `render_click` no botão e assert que loading ou nova mensagem (pode mockar segundo `interview_done` se necessário — se complexo, assert só que o botão existe com o label).

**Step 4:** `mix test test/elder_web/live/skill_run_live_test.exs`

---

### Task 7: `ContextBuilder` (opcional, YAGNI se skill já for auto-contido)

**Files:**
- Modify: `lib/elder/llm/context_builder.ex` (somente se quiser reutilizar)
- Modify: `test/elder/llm/context_builder_test.exs`

Se o prompt JSON ficar muito longo no skill, extrair um parágrafo fixo “Output contract” para `ContextBuilder.build_conversation/2` quando `skill.slug == "create-asana-task-review"` — **evitar** acoplamento por slug se possível; preferível manter tudo no `skill.md` até surgir um segundo interview skill.

**Critério:** pular esta task a menos que o time queira DRY entre skills; se pular, marcar N/A no PR.

---

### Task 8: Documentação e verificação final

**Files:**
- Optional: `docs/plans/2026-04-08-asana-review-structured-discovery-design.md` (se quiser separar design aprovado; senão este plano basta)

**Step 1:** `mix test`

**Step 2:** `mix credo` (corrigir issues novas apenas)

**Step 3:** Smoke manual: rodar app, skill Create Asana Task, brief vago → ver draft + pergunta; brief completo → `ready` rápido; clicar sugestão → nova rodada.

---

## Referências de código atuais

- Entrevista: `lib/elder_web/live/skill_run_live.ex` (`:chatting`, `interview_run`, `handle_info` `[READY]`)
- Contexto LLM: `lib/elder/llm/context_builder.ex`
- Chamada síncrona: `lib/elder/llm/client.ex` → `{:interview_done, result}`
- Prompt review: `priv/skills/create-asana-task-review/skill.md`

---

## Execution handoff

**Plan complete and saved to `docs/plans/2026-04-08-asana-review-structured-discovery.md`. Two execution options:**

**1. Subagent-Driven (this session)** — Dispatch a fresh subagent per task, review between tasks, fast iteration. **REQUIRED SUB-SKILL:** @superpowers:subagent-driven-development

**2. Parallel Session (separate)** — New session with @superpowers:executing-plans in a dedicated worktree, batch execution with checkpoints.

**Which approach?**
