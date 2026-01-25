defmodule Lanpartyseating.Mixfile do
  use Mix.Project

  def project do
    [
      app: :lanpartyseating,
      version: "0.0.1",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      listeners: [Phoenix.CodeReloader],
      aliases: aliases(),
      deps: deps(),
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Lanpartyseating.Application, []},
      extra_applications: [:logger, :runtime_tools],
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:swoosh, "~> 1.4"},
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.19"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_view, "~> 1.1.19"},
      {:phoenix_live_dashboard, "~> 0.8.5"},
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:phoenix_pubsub, "~> 2.2"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.4.0"},
      {:bandit, "~> 1.10"},
      {:timex, "~> 3.7.13"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:lazy_html, ">= 0.0.0", only: :test},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry_exporter, "~> 1.10"},
      {:opentelemetry_phoenix, "~> 2.0"},
      # Removed opentelemetry_liveview (superseded by opentelemetry_phoenix 2.0+ with built-in LiveView support)
      {:opentelemetry_bandit, "~> 0.3"},
      {:heartcheck, "~> 0.4"},
      {:prom_ex, "~> 1.11"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:freedom_formatter, ">= 2.0.0", only: :dev},
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
      "assets.deploy": [
        "cmd --cd assets npm run deploy",
        "esbuild default --minify",
        "phx.digest",
      ],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
    ]
  end
end
