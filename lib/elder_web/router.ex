defmodule ElderWeb.Router do
  use ElderWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElderWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug ElderWeb.Plugs.SetCurrentUser
  end

  pipeline :require_auth do
    plug ElderWeb.Plugs.RequireAuth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ElderWeb do
    pipe_through :browser

    live "/", HomepageLive
  end

  scope "/auth", ElderWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :logout
  end

  scope "/", ElderWeb do
    pipe_through [:browser, :require_auth]

    live_session :authenticated, on_mount: [ElderWeb.LiveAuth] do
      live "/dashboard", DashboardLive
    end
  end

  if Application.compile_env(:elder, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ElderWeb.Telemetry
    end
  end
end
