defmodule LanpartyseatingWeb.Router do
  use LanpartyseatingWeb, :router

  import LanpartyseatingWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:put_root_layout, {LanpartyseatingWeb.Layouts, :root})
    plug(:fetch_current_scope_for_user)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Healthcheck scope
  scope "/" do
    pipe_through(:browser)

    forward("/healthz", HeartCheck.Plug, heartcheck: LanpartyseatingWeb.HealthCheck)
  end

  # Public routes (no auth required)
  scope "/", LanpartyseatingWeb do
    pipe_through(:browser)

    live_session :public,
      on_mount: [
        {LanpartyseatingWeb.UserAuth, :mount_current_scope},
        LanpartyseatingWeb.Nav,
      ],
      layout: {LanpartyseatingWeb.Layouts, :live} do
      live("/", DisplayLive, :index)
      live("/stations", StationsLive, :index)
    end
  end

  # Authentication routes (login pages)
  scope "/", LanpartyseatingWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
    get "/login/badge", BadgeSessionController, :new
    post "/login/badge", BadgeSessionController, :create
  end

  # Logout route (always accessible when logged in)
  scope "/", LanpartyseatingWeb do
    pipe_through(:browser)

    delete "/logout", UserSessionController, :delete
  end

  # Admin routes (require authentication - user or badge)
  scope "/", LanpartyseatingWeb do
    pipe_through([:browser, :require_authenticated_user])

    live_session :admin,
      on_mount: [
        {LanpartyseatingWeb.UserAuth, :mount_current_scope},
        LanpartyseatingWeb.Nav,
        {LanpartyseatingWeb.UserAuth, :ensure_authenticated},
      ],
      layout: {LanpartyseatingWeb.Layouts, :live} do
      live("/tournaments", TournamentsLive, :index)
      live("/logs", LogsLive, :index)
      live("/maintenance", MaintenanceLive, :index)

      # Settings routes - unified settings page with sidebar
      live("/settings", SettingsLive, :index)
      live("/settings/seating", SettingsLive, :seating)
      live("/settings/users", SettingsLive, :users)
      live("/settings/badges", SettingsLive, :badges)
      live("/settings/scanners", SettingsLive, :scanners)
    end
  end

  # User profile routes (require FULL user authentication - not badge)
  scope "/", LanpartyseatingWeb do
    pipe_through([:browser, :require_authenticated_user])

    live_session :user_profile,
      on_mount: [
        {LanpartyseatingWeb.UserAuth, :mount_current_scope},
        LanpartyseatingWeb.Nav,
        {LanpartyseatingWeb.UserAuth, :ensure_user_authenticated},
      ],
      layout: {LanpartyseatingWeb.Layouts, :live} do
      live("/profile", ProfileLive, :index)
    end
  end

  # Enables LiveDashboard only for development
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: LanpartyseatingWeb.Telemetry)
    end
  end
end
