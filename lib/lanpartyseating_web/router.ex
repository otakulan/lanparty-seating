defmodule LanpartyseatingWeb.Router do
  use LanpartyseatingWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_root_layout, {LanpartyseatingWeb.LayoutView, :app}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LanpartyseatingWeb do
    pipe_through :browser # Use the default browser stack

    live_session :nav, on_mount: [
      LanpartyseatingWeb.Nav
    ] do
      live "/", IndexControllerLive, :index
      live "/participants", ParticipantsControllerLive, :index
      live "/settings", SettingsControllerLive, :index
      live "/display", DisplayControllerLive, :index
      live "/management", ManagementControllerLive, :index
      live "/tournaments", TournamentsControllerLive, :index
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
      pipe_through :browser
      live_dashboard "/dashboard", metrics: LanpartyseatingWeb.Telemetry
    end
  end
end
