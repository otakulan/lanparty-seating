# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :lanpartyseating,
  ecto_repos: [Lanpartyseating.Repo]

# Configures the endpoint
config :lanpartyseating, LanpartyseatingWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Ao+QQ96siUJna1mFAy+I+gVIcbTq/iNm9htrJQI0LcNBAm9KiV+xsaoJimsFNEzn",
  render_errors: [view: LanpartyseatingWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Lanpartyseating.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
