import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :lanpartyseating,
       LanpartyseatingWeb.Endpoint,
       http: [port: 4001],
       server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Configure your database
db_port = String.to_integer(System.get_env("PGPORT") || "5021")
db_host = System.get_env("PGHOST") || "localhost"
db_user = System.get_env("PGUSER") || "postgres"
db_password = System.get_env("PGPASSWORD") || "postgres"
db_name = System.get_env("PGDATABASE") || "lanpartyseating_test"

config :lanpartyseating,
       Lanpartyseating.Repo,
       adapter: Ecto.Adapters.Postgres,
       username: db_user,
       password: db_password,
       database: db_name,
       hostname: db_host,
       port: db_port,
       pool: Ecto.Adapters.SQL.Sandbox
