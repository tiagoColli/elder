defmodule ElderWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug that halts the connection and redirects to `/` when `:current_user` is not assigned.
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
