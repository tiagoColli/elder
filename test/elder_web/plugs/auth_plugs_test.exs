defmodule ElderWeb.Plugs.AuthPlugsTest do
  use ElderWeb.ConnCase, async: true

  import Elder.Factory

  alias ElderWeb.Plugs.RequireAuth
  alias ElderWeb.Plugs.SetCurrentUser

  describe "SetCurrentUser" do
    test "assigns current_user when user_id is in session", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> bypass_through(ElderWeb.Router, :browser)
        |> get("/")
        |> put_session(:user_id, user.id)
        |> SetCurrentUser.call(%{})

      assert conn.assigns.current_user.id == user.id
    end

    test "assigns nil when no user_id in session", %{conn: conn} do
      conn =
        conn
        |> bypass_through(ElderWeb.Router, :browser)
        |> get("/")
        |> SetCurrentUser.call(%{})

      assert conn.assigns.current_user == nil
    end

    test "assigns nil when user_id points to deleted user", %{conn: conn} do
      conn =
        conn
        |> bypass_through(ElderWeb.Router, :browser)
        |> get("/")
        |> put_session(:user_id, -1)
        |> SetCurrentUser.call(%{})

      assert conn.assigns.current_user == nil
    end
  end

  describe "RequireAuth" do
    test "passes through when current_user is assigned", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> bypass_through(ElderWeb.Router, :browser)
        |> get("/")
        |> assign(:current_user, user)
        |> RequireAuth.call(%{})

      refute conn.halted
    end

    test "halts and redirects when current_user is nil", %{conn: conn} do
      conn =
        conn
        |> bypass_through(ElderWeb.Router, :browser)
        |> get("/")
        |> assign(:current_user, nil)
        |> RequireAuth.call(%{})

      assert conn.halted
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must be logged in"
    end

    test "halts when current_user is not assigned at all", %{conn: conn} do
      conn =
        conn
        |> bypass_through(ElderWeb.Router, :browser)
        |> get("/")
        |> RequireAuth.call(%{})

      assert conn.halted
      assert redirected_to(conn) == "/"
    end
  end
end
