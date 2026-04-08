defmodule ElderWeb.AuthController do
  @moduledoc """
  Handles Google OAuth request, callback, and logout.

  On successful callback, upserts the user and stores `user_id` in the session.
  """

  use ElderWeb, :controller

  alias Elder.Accounts

  require Logger

  plug Ueberauth

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    Logger.warning("Auth | callback | error:oauth_failure",
      feature: "Auth",
      step: "callback"
    )

    conn
    |> put_flash(:error, "Authentication failed.")
    |> redirect(to: ~p"/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Accounts.find_or_create_user(auth) do
      {:ok, user} ->
        Logger.info("Auth | callback | user_id:#{user.id} | ok",
          feature: "Auth",
          step: "callback"
        )

        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: ~p"/dashboard")

      {:error, _reason} ->
        Logger.error("Auth | callback | error:upsert_failed",
          feature: "Auth",
          step: "callback"
        )

        conn
        |> put_flash(:error, "Something went wrong during sign in.")
        |> redirect(to: ~p"/")
    end
  end

  def logout(conn, _params) do
    user_id = get_session(conn, :user_id)

    Logger.info("Auth | logout | user_id:#{user_id} | ok",
      feature: "Auth",
      step: "logout"
    )

    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end
end
