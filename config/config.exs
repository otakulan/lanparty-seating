# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# esbuild config
config :esbuild,
  path: System.get_env("MIX_ESBUILD_PATH"),
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/js --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)},
  ]

# General application configuration
config :lanpartyseating,
  ecto_repos: [Lanpartyseating.Repo]

# Configures the endpoint
config :lanpartyseating, LanpartyseatingWeb.Endpoint,
  http: [port: 4000, ip: {0, 0, 0, 0, 0, 0, 0, 0}],
  url: [host: "localhost"],
  secret_key_base: "Ao+QQ96siUJna1mFAy+I+gVIcbTq/iNm9htrJQI0LcNBAm9KiV+xsaoJimsFNEzn",
  render_errors: [
    formats: [html: LanpartyseatingWeb.ErrorHTML, json: LanpartyseatingWeb.ErrorJSON],
    layout: false,
  ],
  pubsub_server: Lanpartyseating.PubSub,
  live_view: [signing_salt: "pI2/ZGL+YxiVnXyV3tChX7ruYB8/etKY"],
  adapter: Bandit.PhoenixAdapter

# Configures PromEx
config :lanpartyseating, Lanpartyseating.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
