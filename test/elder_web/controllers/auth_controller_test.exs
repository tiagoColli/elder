defmodule ElderWeb.AuthControllerTest do
  use ElderWeb.ConnCase, async: true

  import Elder.Factory

  describe "callback/2 with successful auth" do
    test "creates user and redirects to dashboard", %{conn: conn} do
      auth = build(:ueberauth_auth)

      conn =
        conn
        |> bypass_through(ElderWeb.Router, :browser)
        |> get("/")
        |> assign(:ueberauth_auth, auth)
        |> ElderWeb.AuthController.callback(%{})

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :user_id)
    end

    test "sets user_id in session", %{conn: conn} do
      auth = build(:ueberauth_auth)

      conn =
        conn
        |> bypass_through(ElderWeb.Router, :browser)
        |> get("/")
        |> assign(:ueberauth_auth, auth)
        |> ElderWeb.AuthController.callback(%{})

      user_id = get_session(conn, :user_id)
      assert user_id
      assert Elder.Accounts.get_user(user_id)
    end
  end

  describe "callback/2 with auth failure" do
    test "redirects to homepage with error flash", %{conn: conn} do
      conn =
        conn
        |> bypass_through(ElderWeb.Router, :browser)
        |> get("/")
        |> assign(:ueberauth_failure, %Ueberauth.Failure{})
        |> ElderWeb.AuthController.callback(%{})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Authentication failed."
    end
  end

  describe "logout/2" do
    test "drops session and redirects to homepage", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> bypass_through(ElderWeb.Router, :browser)
        |> get("/")
        |> put_session(:user_id, user.id)
        |> ElderWeb.AuthController.logout(%{})

      assert redirected_to(conn) == "/"
    end
  end
end
