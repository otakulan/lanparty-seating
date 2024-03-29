defmodule Lanpartyseating.Mixfile do
  use Mix.Project

  def project do
    [
      app: :lanpartyseating,
      version: "0.0.1",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Lanpartyseating.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.6"},
      {:phoenix_ecto, "~> 4.4.2"},
      {:ecto_sql, "~> 3.10.1"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.3.1"},
      {:phoenix_live_view, "~> 0.20.0"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:phoenix_live_reload, "~> 1.4.1", only: :dev},
      {:phoenix_pubsub, "~> 2.1.3"},
      {:telemetry_metrics, "~> 0.6.1"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.22.3"},
      {:jason, "~> 1.4.0"},
      {:plug_cowboy, "~> 2.6.1"},
      {:timex, "~> 3.7.11"},
      {:esbuild, "~> 0.7.1", runtime: Mix.env() == :dev},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_ecto, "~> 1.0"},
      {:opentelemetry_exporter, "~> 1.4"},
      {:opentelemetry_phoenix, "~> 1.1"},
      {:opentelemetry_liveview, "~> 1.0.0-rc"},
      {:opentelemetry_cowboy, "~> 0.2"},
      {:heartcheck, "~> 0.4"},
      {:prom_ex, "~> 1.8.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "assets.deploy": ["cmd --cd assets npm run deploy", "esbuild default --minify", "phx.digest"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
