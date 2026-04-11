defmodule ElderWeb.SkillRunLiveTest do
  use ElderWeb.ConnCase, async: false

  import Mox
  import Phoenix.LiveViewTest
  import Elder.Factory

  setup :set_mox_global

  setup do
    stub(Elder.LLM.ClientMock, :stream, fn _context, _model, _topic -> :ok end)
    stub(Elder.LLM.ClientMock, :call, fn _context, _model, _topic -> :ok end)
    stub(Elder.LLM.ClientMock, :generate_object, fn _context, _schema, _model, _topic -> :ok end)
    stub(Elder.Asana.ClientMock, :list_workspaces, fn -> {:ok, []} end)
    :ok
  end

  defp authed_conn(conn, user) do
    conn
    |> bypass_through(ElderWeb.Router, :browser)
    |> get("/")
    |> put_session(:user_id, user.id)
    |> send_resp(200, "")
    |> recycle()
  end

  describe "mount/3" do
    test "renders input form for authenticated user with valid skill slug", %{conn: conn} do
      user = insert(:user)

      {:ok, _view, html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      assert html =~ "Create Asana Task"
      assert html =~ "Your brief"
    end

    test "redirects to skills list when slug does not exist", %{conn: conn} do
      user = insert(:user)

      assert {:error, {:live_redirect, %{to: "/skills"}}} =
               live(authed_conn(conn, user), ~p"/skills/nonexistent-skill/run")
    end

    test "redirects to homepage when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/skills/create-asana-task/run")
    end
  end

  describe "handle_event generate" do
    test "shows validation error when user input is empty", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      html =
        view
        |> element("form")
        |> render_submit(%{"user_input" => ""})

      assert html =~ "Please describe what you need"
    end
  end

  describe "handle_event reset" do
    test "clears error and returns to idle with form visible", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      send(view.pid, {:llm_error, :timeout})
      assert render(view) =~ "Generation failed"

      html = render_click(view, "reset", %{})

      assert html =~ "Your brief"
      refute html =~ "Generation failed"
    end
  end

  describe "handle_info" do
    test "llm_error shows error message and form remains visible", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      send(view.pid, {:llm_error, :upstream_timeout})

      html = render(view)
      assert html =~ "Generation failed"
      assert html =~ "Your brief"
    end

    test "asana_result success shows task URL and success message", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      task_url = "https://app.asana.com/0/123456/789012"
      send(view.pid, {:asana_result, {:ok, %{task_url: task_url}}})

      html = render(view)
      assert html =~ task_url
      assert html =~ "View in Asana"
    end

    test "asana_result error shows error message", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      send(view.pid, {:asana_result, {:error, :unauthorized}})

      html = render(view)
      assert html =~ "Could not create Asana task"
    end

    test "asana_workspaces_loaded error shows error message", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      send(view.pid, {:asana_workspaces_loaded, {:error, :forbidden}})

      html = render(view)
      assert html =~ "Could not load Asana workspaces"
    end
  end

  describe "handle_info llm_done" do
    test "saves run and transitions to :done phase, showing generated output", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task-review/run")

      view
      |> element("form")
      |> render_submit(%{"user_input" => "Create a handover task for the engineering team"})

      send(view.pid, {
        :llm_done,
        %{
          output: "<body><h1>Handover task</h1></body>",
          cost_usd: 0.0015,
          model: "google:gemini-2.5-flash"
        }
      })

      html = render(view)
      assert html =~ "Generated output"
      assert html =~ "Send to Asana"
    end

    test "shows error and returns to :idle when save_run fails", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task-review/run")

      send(view.pid, {
        :llm_done,
        %{output: "<body>output</body>", cost_usd: 0.001, model: "google:gemini-2.5-flash"}
      })

      html = render(view)
      assert html =~ "Failed to save result"
    end
  end

  describe "handle_info llm_object_done" do
    test "transitions to :previewing phase and shows task name on success", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task-review/run")

      view
      |> element("form")
      |> render_submit(%{"user_input" => "Build an audit log page for notification settings"})

      send(view.pid, {
        :llm_object_done,
        {:ok,
         %{
           object: %{
             "name" => "Audit log page",
             "html_notes" => "<body><p>Build the audit log.</p></body>"
           },
           cost_usd: 0.002,
           model: "google:gemini-2.5-flash"
         }}
      })

      html = render(view)
      assert html =~ "Audit log page"
      assert html =~ "Task Preview"
    end

    test "shows error and returns to :idle when task draft is invalid", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task-review/run")

      view
      |> element("form")
      |> render_submit(%{"user_input" => "Some brief"})

      send(view.pid, {
        :llm_object_done,
        {:ok,
         %{
           object: %{"missing_name" => true},
           cost_usd: 0.001,
           model: "google:gemini-2.5-flash"
         }}
      })

      html = render(view)
      assert html =~ "Could not parse the generated task"
      assert html =~ "Your brief"
    end

    test "shows error on LLM failure", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task-review/run")

      send(view.pid, {:llm_object_done, {:error, %{status: 503}}})

      html = render(view)
      assert html =~ "temporarily unavailable"
    end
  end

  describe "handle_info asana loading events" do
    test "asana_workspaces_loaded success clears loading state", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task-review/run")

      view
      |> element("form")
      |> render_submit(%{"user_input" => "Create a task for the team handover"})

      send(view.pid, {
        :llm_done,
        %{output: "<body>output</body>", cost_usd: 0.001, model: "google:gemini-2.5-flash"}
      })

      send(view.pid, {
        :asana_workspaces_loaded,
        {:ok, [%{gid: "ws-123", name: "Acme Corp Workspace"}]}
      })

      html = render(view)
      assert html =~ "Acme Corp Workspace"
    end

    test "asana_projects_loaded error shows error message", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      send(view.pid, {:asana_projects_loaded, {:error, :forbidden}})

      html = render(view)
      assert html =~ "Could not load Asana projects"
    end

    test "asana_sections_loaded error shows error message", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      send(view.pid, {:asana_sections_loaded, {:error, :not_found}})

      html = render(view)
      assert html =~ "Could not load Asana sections"
    end

    test "asana_projects_loaded success stores projects in assigns without error", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      send(view.pid, {
        :asana_projects_loaded,
        {:ok, [%{gid: "proj-1", name: "Marketing Q4"}, %{gid: "proj-2", name: "Engineering"}]}
      })

      html = render(view)
      refute html =~ "Could not load Asana projects"
    end
  end

  describe "handle_info interview_done ready status" do
    test "ready with complete fields and structured skill transitions to :processing", %{
      conn: conn
    } do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      view
      |> element("form")
      |> render_submit(%{"user_input" => "Create a campaign brief for Q4 product launch"})

      json = ~S"""
      {"status":"ready","draft":{"name":"Q4 Product Launch","responsible_email":"owner@company.com","description":"Full campaign brief for the product launch.","due_on":"2026-06-01"},"skipped_fields":[],"assistant_message":"All set. Ready to generate."}
      """

      send(view.pid, {:interview_done, {:ok, json}})

      html = render(view)
      assert html =~ "Generating task"
    end

    test "ready with missing required fields re-prompts with missing fields message", %{
      conn: conn
    } do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      view
      |> element("form")
      |> render_submit(%{"user_input" => "Create a task without description"})

      json = ~S"""
      {"status":"ready","draft":{"name":"Task without description","responsible_email":null,"description":null,"due_on":null},"skipped_fields":[],"assistant_message":"Ready."}
      """

      send(view.pid, {:interview_done, {:ok, json}})

      html = render(view)
      assert html =~ "description"
      assert html =~ "still need"
    end

    test "interview_done error result shows error and clears loading", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      view
      |> element("form")
      |> render_submit(%{"user_input" => "Some brief"})

      send(view.pid, {:interview_done, {:error, %{status: 429}}})

      html = render(view)
      assert html =~ "temporarily unavailable"
      refute html =~ "Thinking"
    end
  end

  describe "handle_event chat_reply" do
    test "sends interview message and shows loading indicator", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      view
      |> element("form")
      |> render_submit(%{"user_input" => "I need a task about the annual report"})

      json = ~S"""
      {"status":"continue","draft":{"name":"Annual report task","responsible_email":null,"description":null,"due_on":null},"skipped_fields":[],"assistant_message":"Got the title.","question":"Can you describe this task?"}
      """

      send(view.pid, {:interview_done, {:ok, json}})

      view
      |> element("form[phx-submit=chat_reply]")
      |> render_submit(%{"message" => "The annual report needs a full summary."})

      assert render(view) =~ "Thinking"
    end

    test "ignores empty message submission", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      view
      |> element("form")
      |> render_submit(%{"user_input" => "Some brief"})

      json = ~S"""
      {"status":"continue","draft":{"name":null,"responsible_email":null,"description":null,"due_on":null},"skipped_fields":[],"assistant_message":"Hi","question":"What's the title?"}
      """

      send(view.pid, {:interview_done, {:ok, json}})

      view
      |> element("form[phx-submit=chat_reply]")
      |> render_submit(%{"message" => ""})

      refute render(view) =~ "Thinking"
    end
  end

  describe "interview structured JSON (create-asana-task review)" do
    test "interview_done continue shows assistant message, draft, and clears loading", %{
      conn: conn
    } do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      view
      |> element("form")
      |> render_submit(%{"user_input" => "I need a task about the report"})

      assert render(view) =~ "Thinking"

      json = ~S"""
      {"status":"continue","draft":{"name":"Report task","responsible_email":null,"description":null,"due_on":null},"skipped_fields":[],"assistant_message":"Got it — we'll use that title.","question":"Who should own it?"}
      """

      send(view.pid, {:interview_done, {:ok, json}})

      html = render(view)
      assert html =~ "Got it — we&#39;ll use that title."
      assert html =~ "Report task"
      assert html =~ ~s(data-testid="interview-draft")
      assert html =~ ~s(data-testid="interview-question")
      assert html =~ "Who should own it?"
      refute html =~ "Thinking"
    end

    test "interview_done invalid JSON shows friendly error unless legacy [READY]", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      view
      |> element("form")
      |> render_submit(%{"user_input" => "Brief"})

      send(view.pid, {:interview_done, {:ok, "plain text, not json"}})

      html = render(view)
      assert html =~ "could not be read"
      refute html =~ "Thinking"
    end

    test "suggestion chip sends message and shows loading", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/create-asana-task/run")

      view
      |> element("form")
      |> render_submit(%{"user_input" => "Unclear owner"})

      json = ~S"""
      {"status":"continue","draft":{"name":null,"responsible_email":null,"description":null,"due_on":null},"skipped_fields":[],"assistant_message":"Who owns this?","suggestions":[{"label":"I will own it","value":"I'll take ownership."}]}
      """

      send(view.pid, {:interview_done, {:ok, json}})

      html = render(view)
      assert html =~ "I will own it"

      view
      |> element("button", "I will own it")
      |> render_click()

      assert render(view) =~ "Thinking"
    end
  end

  describe "handle_event generate (direct structured path)" do
    test "transitions to :processing and calls generate_object", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(authed_conn(conn, user), ~p"/skills/test-structured-direct/run")

      expect(Elder.LLM.ClientMock, :generate_object, fn _context, _schema, _model, _topic ->
        :ok
      end)

      view
      |> element("form")
      |> render_submit(%{"user_input" => "Create a task for the Q4 launch"})

      html = render(view)
      assert html =~ "Generating task"
    end
  end
end
