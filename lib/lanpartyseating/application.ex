defmodule Lanpartyseating.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # :opentelemetry_cowboy.setup()
    # OpentelemetryPhoenix.setup(adapter: :cowboy2)
    # OpentelemetryLiveView.setup()
    # OpentelemetryEcto.setup([:lanpartyseating, :repo])

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Endpoint (http/https)
      LanpartyseatingWeb.Endpoint,
      # Start prometheus metrics
      Lanpartyseating.PromEx,
      # Start the Ecto repository
      Lanpartyseating.Repo,
      # Start the Telemetry supervisor
      LanpartyseatingWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, [name: Lanpartyseating.PubSub, adapter: Phoenix.PubSub.PG2]},
      # Start a worker by calling: Lanpartyseating.Worker.start_link(arg)
      # {Lanpartyseating.Worker, arg}
      {DynamicSupervisor, strategy: :one_for_one, name: Lanpartyseating.ExpirationTaskSupervisor},
      Lanpartyseating.ExpirationKickstarter,
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
end
