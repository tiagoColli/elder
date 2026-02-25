defmodule ElderWeb.Plugs.SetCurrentUser do
  @moduledoc """
  Plug that assigns `:current_user` from the session `user_id`.

  Assigns `nil` when no session is present.
  """

  import Plug.Conn

  alias Elder.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      assign(conn, :current_user, Accounts.get_user(user_id))
    else
      assign(conn, :current_user, nil)
    end
  end
end
