defmodule ElderWeb.SkillRunLiveTest do
  use ElderWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Elder.Factory

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
end
