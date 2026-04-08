defmodule ElderWeb.SkillsLiveTest do
  use ElderWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Elder.Factory

  describe "mount/3" do
    test "renders skill listing for an authenticated user", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> bypass_through(ElderWeb.Router, :browser)
        |> get("/")
        |> put_session(:user_id, user.id)
        |> send_resp(200, "")
        |> recycle()

      {:ok, _view, html} = live(conn, ~p"/skills")

      assert html =~ "Skills"
      assert html =~ "Create Asana Task"
    end

    test "redirects to homepage when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/skills")
    end
  end
end
