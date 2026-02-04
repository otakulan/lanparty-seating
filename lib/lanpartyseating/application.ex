defmodule Lanpartyseating.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit, liveview: true)
    OpentelemetryEcto.setup([:lanpartyseating, :repo])

    children = [
      # Database must be ready before anything queries it
      Lanpartyseating.Repo,
      {Task, fn -> ensure_settings_exist() end},
      # Telemetry and metrics
      LanpartyseatingWeb.Telemetry,
      Lanpartyseating.PromEx,
      # PubSub system (Presence depends on this)
      {Phoenix.PubSub, name: Lanpartyseating.PubSub},
      LanpartyseatingWeb.Presence,
      # Task supervisor for fire-and-forget async operations (e.g., scanner last_seen updates)
      {Task.Supervisor, name: Lanpartyseating.TaskSupervisor},
      # Expiration task infrastructure (DynamicSupervisor for long-running scheduled tasks)
      {DynamicSupervisor, strategy: :one_for_one, name: Lanpartyseating.ExpirationTaskSupervisor},
      Lanpartyseating.ExpirationKickstarter,
      # Endpoint starts last - accept connections only when ready
      LanpartyseatingWeb.Endpoint,
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Lanpartyseating.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    LanpartyseatingWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp ensure_settings_exist() do
    alias Lanpartyseating.{Repo, Setting}
    case Repo.get(Setting, 1) do
      nil ->
        IO.puts("Creating default settings row")
        %Setting{}
        |> Repo.insert!()
    end
  end
end
