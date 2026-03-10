defmodule LanpartyseatingWeb.Router do
  use LanpartyseatingWeb, :router

  import LanpartyseatingWeb.UserAuth

  alias LanpartyseatingWeb.Plugs.ScannerAuth

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

  pipeline :api_authenticated do
    plug(:accepts, ["json"])
    plug(ScannerAuth)
  end

  pipeline :api_spec do
    plug(:accepts, ["json"])
    plug(OpenApiSpex.Plug.PutApiSpec, module: LanpartyseatingWeb.ApiSpec)
  end

  # Healthcheck scope
  scope "/" do
    pipe_through(:browser)

    forward("/healthz", HeartCheck.Plug, heartcheck: LanpartyseatingWeb.HealthCheck)
  end

  # Public routes (no auth required)
  scope "/", LanpartyseatingWeb do
    pipe_through(:browser)

    # Carousel image serving (plain controller, no LiveView)
    get "/carousel/images/:id", CarouselImageController, :show

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

      # Settings routes - separate LiveViews with shared sidebar navigation
      live("/settings", Settings.SeatingLive, :index)
      live("/settings/seating", Settings.SeatingLive, :seating)
      live("/settings/reservations", Settings.ReservationsLive, :reservations)
      live("/settings/users", Settings.UsersLive, :users)
      live("/settings/badges", Settings.BadgesLive, :badges)
      live("/settings/carousel", Settings.CarouselLive, :carousel)
      live("/settings/scanners", Settings.ScannersLive, :scanners)
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

  # API v1 routes (authenticated with scanner token)
  scope "/api/v1", LanpartyseatingWeb.Api.V1 do
    pipe_through(:api_authenticated)

    post "/reservations/cancel", ReservationController, :cancel
  end

  # Enables LiveDashboard only for development
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: LanpartyseatingWeb.Telemetry)
    end

    # OpenAPI documentation
    scope "/api" do
      pipe_through(:api_spec)
      get "/openapi", OpenApiSpex.Plug.RenderSpec, []
    end

    # Swagger UI (needs browser pipeline for HTML)
    scope "/api" do
      pipe_through(:browser)
      get "/docs", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"
    end
  end
end
