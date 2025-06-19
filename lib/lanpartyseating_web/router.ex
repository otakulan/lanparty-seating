defmodule LanpartyseatingWeb.Router do
  use LanpartyseatingWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:put_root_layout, {LanpartyseatingWeb.Layouts, :root})
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Healthcheck scope
  scope "/" do
    # Use the default browser stack
    pipe_through(:browser)

    forward("/healthz", HeartCheck.Plug, heartcheck: LanpartyseatingWeb.HealthCheck)
  end

  scope "/", LanpartyseatingWeb do
    # Use the default browser stack
    pipe_through(:browser)

    live_session :nav,
      on_mount: [
        LanpartyseatingWeb.Nav,
        LanpartyseatingWeb.Public
      ] do
      live("/", DisplayLive, :index)
      live("/autoassign", AutoAssignLive, :index)
      live("/selfsign", SelfSignLive, :index)
      live("/cancellation", CancellationLive, :index)
      # ADMIN PAGES
      #live("/tournaments", TournamentsLive, :index)
      #live("/settings", SettingsLive, :index)
      #live("/logs", LogsLive, :index)
    end
  end

  scope "/", LanpartyseatingWeb do
    pipe_through(:browser)

    live_session :admin,
      on_mount: [
        LanpartyseatingWeb.AdminBadgeCheckLive,
        LanpartyseatingWeb.Nav
      ] do
      live("/login", AdminBadgeLoginLive, :index)
      get("/auth", TestController, :check_badge)
      get("/reset_admin", TestController, :reset_admin)
      # ADMIN PAGES
      live("/tournaments", TournamentsLive, :index)
      live("/settings", SettingsLive, :index)
      live("/logs", LogsLive, :index)
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", LanpartyseatingWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: LanpartyseatingWeb.Telemetry)
    end
  end
end
