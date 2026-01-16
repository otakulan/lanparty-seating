# LAN Party Seating

Real-time web application for managing gaming station reservations at LAN party events.

## Development Setup

If you are running NixOS, make sure flakes are enabled.

On other operating systems/distributions, install Nix using the [Determinate Systems Nix installer](https://github.com/DeterminateSystems/nix-installer):

```console
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Consider installing [direnv](https://direnv.net/) to automatically install the project's nix shell when you `cd` into the folder. If you have direnv installed, simply run `direnv allow` and follow the instructions below.

If you don't use direnv, activate the nix shell using `nix shell --impure`.

To start lanparty-seating:

1. **Start PostgreSQL** (keep running in a dedicated terminal): `devenv up`
2. Install dependencies: `mix deps.get`
3. Create and migrate database: `mix ecto.create && mix ecto.migrate`
4. Seed database: `mix ecto.reset`
5. Install Node.js dependencies: `cd assets && yarn install --dev && cd ..`
6. Deploy assets: `mix assets.deploy`
7. Start Phoenix: `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Environment Variables

Copy `.env.sample` to `.env` for local development:

```bash
cp .env.sample .env
```

The `.envrc` file automatically loads `.env` when using direnv. Edit `.env` to configure optional integrations like OpenTelemetry tracing.

**Note:** Database configuration for development is handled automatically by `devenv up` - no `DATABASE_URL` needed locally.

## Useful Commands

### Development

```bash
mix phx.server              # Start dev server
mix phx.routes              # List all routes
mix ecto.reset              # Drop, create, migrate, seed DB
iex -S mix phx.server       # Start with IEx REPL
```

### Database

```bash
mix ecto.create             # Create database
mix ecto.migrate            # Run migrations
mix ecto.rollback           # Rollback last migration
mix ecto.gen.migration name # Generate new migration
```

### Code Quality

```bash
mix format                  # Format code
mix test                    # Run tests
```

## Debugging

There are multiple ways to debug elixir code as shown in the [Debugging](https://elixir-lang.org/getting-started/debugging.html) section of the elixir manual.

In general, you can use the VSCode editor with the recommended extensions for the project to debug in the editor using ElixirLS.

You can also launch the program with the elixir repl using `iex -S mix phx.server` and insert "breakpoints" into the code using `IEx.pry()` in order to make the app break into the repl at that point, allowing you to introspect its state.

**Live Dashboard:** Visit `http://localhost:4000/dashboard` (dev only) to view processes, metrics, and request logs.

## Configuration

### Environment Variables

**Database:**
- `DATABASE_URL` - PostgreSQL connection string

**Web:**
- `PHX_HOST` - Public hostname
- `PORT` - HTTP port (default: 4000)
- `SECRET_KEY_BASE` - Phoenix secret (required)

**Timezone:**
- `TZ=America/Toronto` - Application timezone
- `STORAGE_DIR=/tmp/tzdata` - Timezone data cache

**OTP:**
- `RELEASE_COOKIE` - Erlang distribution cookie (for clustering)

### Grafana

You can configure the app to automatically upload its grafana dashboards to grafana and annotate its lifecycle events in grafana by setting the following environment variables:

- `GRAFANA_ENABLE` - Any value such as `1` enables grafana support
- `GRAFANA_HOST` - URL to the grafana instance
- `GRAFANA_AUTH_TOKEN` - Grafana auth token
- `GRAFANA_DATASOURCE_ID` - Grafana datasource id for the prometheus instance

### OpenTelemetry (OTLP)

Configure OpenTelemetry tracing via `.env` (see `.env.sample`):

- `OTEL_EXPORTER_OTLP_ENDPOINT` - OTLP endpoint (e.g., `https://api.honeycomb.io`)
- `OTEL_EXPORTER_OTLP_HEADERS` - Auth headers (e.g., `x-honeycomb-team=YOUR_TOKEN`)
- `OTEL_SERVICE_NAME` - Service name for traces

## Production Deployment

### Building Container

```bash
nix build .#container                   # Build container image
nix run .#container.copyToDockerDaemon  # Load into Docker
docker run -p 4000:4000 lanparty-seating
```

### Required Environment Variables

```bash
DATABASE_URL=postgresql://user:pass@host:5432/lanpartyseating_prod
SECRET_KEY_BASE=$(mix phx.gen.secret)
PHX_HOST=example.com
PORT=4000
TZ=America/Toronto
```

### Database Setup

```bash
bin/server eval "Lanpartyseating.Release.migrate()"
bin/server eval "Lanpartyseating.Release.seed()"
```

### Manual Release Build

```bash
mix assets.deploy           # Build and digest assets
mix release                 # Build OTP release
```
