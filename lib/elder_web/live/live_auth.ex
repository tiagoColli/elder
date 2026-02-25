defmodule ElderWeb.LiveAuth do
  @moduledoc """
  LiveView `on_mount` hook that enforces authentication.

  Loads the current user from session and assigns `:current_user`.
  Redirects to `/` if the session is missing or the user no longer exists.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias Elder.Accounts

  def on_mount(:default, _params, session, socket) do
    case session["user_id"] do
      nil ->
        {:halt, redirect(socket, to: "/")}

      user_id ->
        user = Accounts.get_user(user_id)

        if user do
          {:cont, assign(socket, :current_user, user)}
        else
          {:halt, redirect(socket, to: "/")}
        end
    end
  end
end
