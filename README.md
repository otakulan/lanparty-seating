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
6. Generate HTTPS certificate: `mix gen_dev_cert`
7. Deploy assets: `mix assets.deploy`
8. Start Phoenix: `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

For WebBluetooth scanner provisioning, use HTTPS at [`localhost:4001`](https://localhost:4001).

### Default Seed Data

#### Development (`mix ecto.reset`)

After running `mix ecto.reset`, the following test data is created from `priv/repo/seeds.exs`:

**Admin User:**
- Email: `admin@otakuthon.com`
- Password: `change-me-on-first-login`
- Name: `Admin`

**Admin Badge** (for badge-based admin access):
- Badge Number: `ADMIN-001`

**Test Badge** (for testing reservations):
- Badge Number: `1`

**Sample Tournaments:**
- 3 tournaments with stations 1-10 locked for the first one

The seed configuration (grid size, timing offset) can be adjusted at the top of `priv/repo/seeds.exs`.

#### Production (`Lanpartyseating.Release.seed()`)

Production seeds (`priv/repo/seeds_prod.exs`) create only the minimal required data:

- Default settings
- 70 stations (10x7 grid)
- Admin user (`admin@otakuthon.com` / `change-me-on-first-login`)

No test badges or sample tournaments are created.

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
bin/lanpartyseating eval "Lanpartyseating.Release.migrate()"
bin/lanpartyseating eval "Lanpartyseating.Release.seed()"
```

### Manual Release Build

```bash
mix assets.deploy           # Build and digest assets
mix release                 # Build OTP release
```

## External Badge Scanner

For exit sign-out stations, the system supports external ESP32-based badge scanners that allow attendees to cancel their reservations by scanning their badge at exit points.

**Hardware Firmware:** [otakulan/lanparty-seating-badge-reader](https://github.com/otakulan/lanparty-seating-badge-reader)

### Server Configuration

1. Configure WiFi credentials in Settings > Scanners (stored encrypted, shared by all scanners)
2. Create a scanner entry (generates a unique API token)
3. Provision the ESP32 via WebBluetooth (sends WiFi + API credentials to device)

### API Endpoint

Scanners call `POST /api/v1/reservations/cancel` with bearer token authentication:

```bash
curl -X POST https://your-server/api/v1/reservations/cancel \
  -H "Authorization: Bearer lpss_..." \
  -H "Content-Type: application/json" \
  -d '{"badge_uid": "ABC123"}'
```

### Development Notes

WebBluetooth provisioning requires a secure context. In development:
- Generate HTTPS certificate: `mix gen_dev_cert`
- Use HTTPS on port 4001: https://localhost:4001
- Or access via `localhost` on HTTP (exempt from HTTPS requirement)

The certificate is generated using OpenSSL (not `mix phx.gen.cert`) for
compatibility with Chrome and OTP 28.

See the [hardware repository](https://github.com/otakulan/lanparty-seating-badge-reader) for firmware setup, hardware requirements, and LED status indicators.
