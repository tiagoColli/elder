defmodule ElderWeb.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint ElderWeb.Endpoint

      use ElderWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import ElderWeb.ConnCase
    end
  end

  setup tags do
    Elder.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
