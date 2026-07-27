# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

config :lanpartyseating,
       :scopes,
       user:
         [
           default: true,
           module: Lanpartyseating.Accounts.Scope,
           assign_key: :current_scope,
           access_path: [:user, :id],
           schema_key: :user_id,
           schema_type: :id,
           schema_table: :users,
           test_data_fixture: Lanpartyseating.AccountsFixtures,
           test_setup_helper: :register_and_log_in_user,
         ]

# esbuild config
config :esbuild,
       version_check: false,
       path: System.get_env("MIX_ESBUILD_PATH") || Path.expand("../assets/node_modules/.bin/esbuild", __DIR__),
       default:
         [
           args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets/js --external:/images/* --sourcemap),
           cd: Path.expand("../assets", __DIR__),
           env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)},
         ],
       theme_core:
         [
           args: ~w(js/theme-core.js --bundle --target=es2017 --format=iife --global-name=ThemeCore --outfile=../priv/static/assets/js/theme-core.js --sourcemap),
           cd: Path.expand("../assets", __DIR__),
           env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)},
         ]

config :tailwind,
       version_check: false,
       path: Path.expand("../assets/node_modules/.bin/tailwindcss", __DIR__),
       default: [
         args: ~w(
           --input=assets/css/app.css
           --output=priv/static/assets/css/app.css
         ),
         cd: Path.expand("..", __DIR__)
       ]

# General application configuration
config :lanpartyseating,
       ecto_repos: [Lanpartyseating.Repo]

# Configures the endpoint
config :lanpartyseating,
       LanpartyseatingWeb.Endpoint,
       http: [port: 4000, ip: {0, 0, 0, 0, 0, 0, 0, 0}],
       url: [host: "localhost"],
       secret_key_base: "Ao+QQ96siUJna1mFAy+I+gVIcbTq/iNm9htrJQI0LcNBAm9KiV+xsaoJimsFNEzn",
       render_errors:
         [
           formats: [html: LanpartyseatingWeb.ErrorHTML, json: LanpartyseatingWeb.ErrorJSON],
           layout: false,
         ],
       pubsub_server: Lanpartyseating.PubSub,
       live_view: [signing_salt: "pI2/ZGL+YxiVnXyV3tChX7ruYB8/etKY"],
       adapter: Bandit.PhoenixAdapter

# Configures PromEx
config :lanpartyseating,
       Lanpartyseating.PromEx,
       disabled: false,
       manual_metrics_start_delay: :no_delay,
       drop_metrics_groups: [],
       grafana: :disabled,
       metrics_server: :disabled

# Configures Elixir's Logger
config :logger,
       :console,
       format: "$time $metadata[$level] $message\n",
       metadata: [:user_id]

config :phoenix, :json_library, Jason

# Mailer configuration (emails not used, but required by phx.gen.auth)
config :lanpartyseating, Lanpartyseating.Mailer, adapter: Swoosh.Adapters.Local

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
