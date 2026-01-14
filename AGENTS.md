# LAN Party Seating - LLM Context Guide

## Project Overview

**Lanparty-Seating** is a real-time web application for managing gaming station reservations at LAN party events (specifically Otakuthon anime/gaming convention). It handles badge scanning, auto-assignment, tournaments, and provides live station availability displays.

**Version:** 0.0.1  
**Primary Language:** Elixir 1.16+ with Phoenix Framework 1.7.6  
**Database:** PostgreSQL via Ecto ORM  
**Frontend:** Phoenix LiveView + Alpine.js + Tailwind CSS  

## Quick Start for Development

```bash
# Prerequisites: Install Nix with flakes support
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Setup environment (with direnv)
direnv allow

# Start services and application
devenv up                                  # Terminal 1: Start PostgreSQL
mix deps.get                               # Install Elixir dependencies
cd assets && yarn install && cd ..         # Install Node.js dependencies
mix ecto.create && mix ecto.migrate        # Create and migrate database
mix ecto.reset                             # Seed database with sample data
mix phx.server                             # Start server at localhost:4000
```

## Architecture Overview

### Layered Architecture Pattern

```
┌─────────────────────────────────────────────────────────┐
│  Web Layer (LiveView, Controllers, Channels)           │
│  - lib/lanpartyseating_web/                             │
└─────────────────────┬───────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│  Business Logic Layer (Pure Functions)                  │
│  - lib/lanpartyseating/logic/                           │
└─────────────────────┬───────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│  Data Access Layer (Repository Pattern)                 │
│  - lib/lanpartyseating/repositories/                    │
└─────────────────────┬───────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│  Database (PostgreSQL via Ecto)                         │
└─────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

1. **Repository Pattern**: All database access goes through dedicated repository modules
2. **Business Logic Separation**: Pure business logic in `logic/` modules, testable and reusable
3. **Phoenix LiveView**: Server-side rendered real-time UI with WebSocket updates
4. **PubSub Broadcasting**: Real-time updates across all connected clients
5. **OTP Task Management**: GenServer-based expiration tasks for time-based reservations
6. **Soft Deletes**: All entities have `deleted_at` timestamp for audit trail
7. **No Authentication**: Badge-based identity system (event context, trusted environment)

## Directory Structure

```
lanparty-seating/
├── lib/
│   ├── lanpartyseating/                   # Core domain logic
│   │   ├── application.ex                 # OTP application supervisor (ENTRY POINT)
│   │   ├── repo.ex                        # Ecto repository
│   │   ├── prom_ex.ex                     # Prometheus metrics
│   │   │
│   │   ├── logic/                         # Business logic (PURE FUNCTIONS)
│   │   │   ├── autoassign_logic.ex        # Station auto-assignment algorithm
│   │   │   ├── badges_logic.ex            # Badge validation and banning
│   │   │   ├── reservation_logic.ex       # Reservation CRUD operations
│   │   │   ├── settings_logic.ex          # Layout settings management
│   │   │   ├── station_logic.ex           # Station availability checks
│   │   │   └── tournaments_logic.ex       # Tournament scheduling
│   │   │
│   │   ├── repositories/                  # Data access (ECTO SCHEMAS)
│   │   │   ├── badge_repo.ex              # badges table
│   │   │   ├── last_assigned_seat_repo.ex # last_assigned_station table
│   │   │   ├── reservation_repo.ex        # reservations table
│   │   │   ├── setting_repo.ex            # settings table
│   │   │   ├── station_layout_repo.ex     # station_layout table
│   │   │   ├── station_repo.ex            # stations table
│   │   │   ├── station_status_repo.ex     # stations_status table
│   │   │   ├── tournament_repo.ex         # tournaments table
│   │   │   └── tournament_reservation_repo.ex  # tournament_reservations table
│   │   │
│   │   └── tasks/                         # Background tasks (GENSERVER)
│   │       ├── expiration_kickstarter.ex  # Restarts expiry tasks on boot
│   │       ├── expire_reservation.ex      # Expires reservations at end_date
│   │       ├── expire_tournament.ex       # Expires tournaments at end_date
│   │       └── start_tournament.ex        # Starts tournaments at start_date
│   │
│   └── lanpartyseating_web/               # Web interface
│       ├── endpoint.ex                    # Phoenix HTTP endpoint
│       ├── router.ex                      # Route definitions (ROUTING)
│       ├── telemetry.ex                   # Telemetry/observability
│       ├── healthcheck.ex                 # /healthz endpoint
│       │
│       ├── channels/                      # WebSocket channels
│       │   ├── desktop_channel.ex         # Desktop client notifications
│       │   ├── desktop_client_socket.ex   # Socket definition
│       │   └── presence.ex                # Presence tracking
│       │
│       ├── components/                    # Reusable LiveView components
│       │   ├── cancellation_modal.ex
│       │   ├── display_modal.ex
│       │   ├── icons.ex
│       │   ├── layouts.ex
│       │   ├── nav.ex
│       │   ├── selfsign_modal.ex
│       │   └── tournament_modal.ex
│       │
│       ├── controllers/                   # Traditional Phoenix controllers
│       │   ├── help_controller.ex
│       │   └── page_controller.ex
│       │
│       └── live/                          # LiveView pages (MAIN UI)
│           ├── display_live.ex            # Public display (station map)
│           ├── autoassign_live.ex         # Badge scanning auto-assignment
│           ├── selfsign_live.ex           # Self-service signup
│           ├── cancellation_live.ex       # Cancel reservations
│           ├── tournaments_live.ex        # Tournament management (admin)
│           ├── settings_live.ex           # Layout settings (admin)
│           ├── logs_live.ex               # Activity logs (admin)
│           └── manhole_live.ex            # Debug console (admin)
│
├── assets/                                # Frontend assets
│   ├── js/
│   │   ├── app.js                         # Alpine.js + LiveView socket
│   │   ├── socket.js                      # Phoenix Socket
│   │   └── desktop_client_socket.js       # Desktop client socket
│   ├── css/
│   │   └── app.css                        # Tailwind CSS entry
│   ├── tailwind.config.js                 # Tailwind configuration
│   └── package.json                       # Node.js dependencies
│
├── config/                                # Configuration files
│   ├── config.exs                         # Base config
│   ├── dev.exs                            # Development environment
│   ├── prod.exs                           # Production environment
│   ├── runtime.exs                        # Runtime env vars
│   └── test.exs                           # Test environment
│
├── priv/
│   ├── repo/
│   │   ├── migrations/                    # Database migrations
│   │   │   └── 20240814023743_squash_migrations.exs
│   │   └── seeds.exs                      # Sample data
│   └── gettext/                           # Translations (FR/EN)
│
├── test/                                  # Test suite (LIMITED COVERAGE)
│
├── mix.exs                                # Elixir project definition
├── flake.nix                              # Nix development environment
├── default.nix                            # Nix package build
└── README.md                              # Setup documentation
```

## Database Schema

### Core Tables

**reservations** - Gaming station reservations
- `id` - Primary key
- `station_id` - FK to stations
- `badge` - Badge serial/UID
- `duration` - Reservation duration (minutes)
- `start_date` - Reservation start (UTC)
- `end_date` - Reservation end (UTC)
- `incident` - Optional incident notes
- `deleted_at` - Soft delete timestamp

**stations** - Physical gaming stations
- `station_number` - Primary key (references station_layout)
- `is_closed` - Manual closure flag
- `deleted_at` - Soft delete timestamp

**station_layout** - Physical layout grid
- `station_number` - Primary key
- `x` - Grid X coordinate
- `y` - Grid Y coordinate
- Unique constraint on (x, y)

**stations_status** - Real-time availability cache
- `station_id` - Primary key
- `is_assigned` - Currently occupied
- `is_broken` - Out of order flag

**tournaments** - Scheduled tournaments
- `id` - Primary key
- `name` - Tournament name
- `start_date` - Start time (UTC)
- `end_date` - End time (UTC)
- `deleted_at` - Soft delete timestamp

**tournament_reservations** - Tournament station locks
- `id` - Primary key
- `tournament_id` - FK to tournaments (cascade delete)
- `station_id` - FK to stations (cascade delete)
- `deleted_at` - Soft delete timestamp

**badges** - Badge identity and banning
- `id` - Primary key
- `serial_key` - Badge serial number
- `uid` - Badge UID
- `is_banned` - Ban flag

**settings** - Layout display settings
- `id` - Primary key
- `row_padding` - Vertical spacing
- `column_padding` - Horizontal spacing
- `horizontal_trailing` - Right padding
- `vertical_trailing` - Bottom padding

**last_assigned_station** - Round-robin tracking
- `id` - Primary key
- `last_assigned_station` - Last assigned station number
- `last_assigned_station_date` - Assignment timestamp

## Routes and User Flows

### Public Routes

**`/` - Display Page** (lib/lanpartyseating_web/live/display_live.ex:33)
- Live station availability grid
- Color-coded stations (available, occupied, reserved for tournaments)
- Upcoming tournaments list
- Real-time updates via PubSub
- Bilingual FR/EN rules and information

**`/autoassign` - Badge Scanning** (lib/lanpartyseating_web/live/autoassign_live.ex:34)
- Staff interface for badge scanning
- Auto-assigns next available station via round-robin algorithm
- Checks badge bans
- Creates reservation with configured duration
- Broadcasts updates to all clients

**`/selfsign` - Self-Service Signup** (lib/lanpartyseating_web/live/selfsign_live.ex:36)
- Participants enter badge number manually
- Select station from available list
- Choose reservation duration
- Self-service reservation creation

**`/cancellation` - Cancel Reservations** (lib/lanpartyseating_web/live/cancellation_live.ex:36)
- Enter badge number to find reservations
- Cancel active or future reservations
- Soft deletes reservation record

### Admin Routes

**`/tournaments` - Tournament Management** (lib/lanpartyseating_web/live/tournaments_live.ex:38)
- Create/edit/delete tournaments
- Schedule start/end times
- Assign stations to tournaments
- Locks stations during tournament time
- Background tasks handle start/end automation

**`/settings` - Layout Settings** (lib/lanpartyseating_web/live/settings_live.ex:39)
- Configure station grid layout
- Set padding and spacing values
- Affects display rendering

**`/logs` - Activity Logs** (lib/lanpartyseating_web/live/logs_live.ex:40)
- View system activity logs
- Reservation history

**`/manhole` - Debug Console** (lib/lanpartyseating_web/live/manhole_live.ex:41)
- Admin debugging interface
- Inspect system state

### API Routes

**`/healthz` - Health Check**
- Returns 200 OK if system healthy
- Used for load balancer/monitoring

## Key Modules and Their Responsibilities

### Application Layer

**`Lanpartyseating.Application`** (lib/lanpartyseating/application.ex:1)
- OTP application supervisor
- Starts: Endpoint, Repo, PromEx, Telemetry, PubSub, Presence, DynamicSupervisor, ExpirationKickstarter

### Business Logic Layer

**`Lanpartyseating.AutoassignLogic`** (lib/lanpartyseating/logic/autoassign_logic.ex)
- `assign_station(badge_serial, duration)` - Auto-assigns next available station
- Round-robin algorithm: splits station list at last assigned position, searches forward, wraps around
- Validates badge not banned
- Creates reservation with calculated end_date
- Updates last_assigned_station tracker
- Broadcasts `station_update` event

**`Lanpartyseating.ReservationLogic`** (lib/lanpartyseating/logic/reservation_logic.ex)
- `create_reservation(attrs)` - Creates reservation, validates availability, schedules expiration task
- `cancel_reservation(id)` - Soft deletes reservation, broadcasts update
- `get_reservation(id)` - Fetches reservation by ID
- `list_reservations()` - Lists all active reservations
- Validates station not locked by tournament

**`Lanpartyseating.StationLogic`** (lib/lanpartyseating/logic/station_logic.ex)
- `is_station_available?(station_id, start_date, end_date)` - Checks overlapping reservations and tournament locks
- `list_available_stations(start_date, end_date)` - Returns list of available stations
- `get_station_status(station_id)` - Returns current status (assigned, broken, closed)

**`Lanpartyseating.TournamentsLogic`** (lib/lanpartyseating/logic/tournaments_logic.ex)
- `create_tournament(attrs)` - Creates tournament, schedules start/end tasks
- `assign_stations(tournament_id, station_ids)` - Locks stations for tournament
- `start_tournament(tournament_id)` - Marks tournament as started
- `end_tournament(tournament_id)` - Releases station locks

**`Lanpartyseating.BadgesLogic`** (lib/lanpartyseating/logic/badges_logic.ex)
- `is_badge_banned?(badge_serial)` - Checks if badge is banned
- `ban_badge(badge_serial)` - Sets is_banned flag
- `get_or_create_badge(badge_serial, uid)` - Ensures badge exists in database

### Repository Layer (Data Access)

All repositories follow similar patterns:
- Ecto schemas define struct and database mapping
- Changesets validate data
- Functions: `get/1`, `list/0`, `create/1`, `update/2`, `delete/1`
- Queries filter `deleted_at IS NULL` by default

Example: **`Lanpartyseating.ReservationRepo`** (lib/lanpartyseating/repositories/reservation_repo.ex)
```elixir
schema "reservations" do
  field :badge, :string
  field :duration, :integer
  field :start_date, :utc_datetime
  field :end_date, :utc_datetime
  field :incident, :string
  field :deleted_at, :utc_datetime
  belongs_to :station, StationRepo
  timestamps()
end
```

### Background Tasks

**`Lanpartyseating.ExpirationKickstarter`** (lib/lanpartyseating/tasks/expiration_kickstarter.ex)
- GenServer that starts on application boot
- Scans database for future reservations and tournaments
- Restarts expiration tasks for each
- Ensures tasks survive application restarts

**`Lanpartyseating.ExpireReservation`** (lib/lanpartyseating/tasks/expire_reservation.ex)
- GenServer task per reservation
- Sleeps until reservation end_date
- Soft deletes reservation (`deleted_at = NOW()`)
- Broadcasts `station_update` to all clients
- Stops after execution

**`Lanpartyseating.ExpireTournament`** (lib/lanpartyseating/tasks/expire_tournament.ex)
- Similar to ExpireReservation but for tournaments
- Releases station locks at tournament end

**`Lanpartyseating.StartTournament`** (lib/lanpartyseating/tasks/start_tournament.ex)
- Marks tournament as started at start_date
- Can trigger notifications or other start logic

### Web Layer

**`LanpartyseatingWeb.Router`** (lib/lanpartyseating_web/router.ex:1)
- Defines all routes
- Browser pipeline: session, CSRF, flash, root layout
- Live session with nav mount hook

**LiveView Pages** - All follow Phoenix LiveView pattern:
- `mount/3` - Initialize socket assigns, subscribe to PubSub topics
- `handle_event/3` - Handle user interactions (button clicks, form submits)
- `handle_info/2` - Handle PubSub broadcasts, update UI
- Templates use HEEx (embedded Elixir HTML)

**Channels** (lib/lanpartyseating_web/channels/)
- `DesktopChannel` - WebSocket channel for desktop client integration
- Broadcasts reservation events to connected desktops
- Uses Phoenix Presence for tracking connected clients

## Real-time Updates (PubSub)

The application uses Phoenix.PubSub for real-time updates:

### Topics

**`"station_update"`** - Station availability changes
- Broadcasted when: reservation created/cancelled, station opened/closed, tournament starts/ends
- Message format: `{:station_updated, station_id}`
- Subscribers: DisplayLive, AutoAssignLive, SelfSignLive

**`"tournament_update"`** - Tournament changes
- Broadcasted when: tournament created/updated/deleted, stations assigned
- Message format: `{:tournament_updated, tournament_id}`
- Subscribers: DisplayLive, TournamentsLive

### Broadcasting Pattern

```elixir
# In logic layer
Phoenix.PubSub.broadcast(
  Lanpartyseating.PubSub,
  "station_update",
  {:station_updated, station_id}
)

# In LiveView
def mount(_params, _session, socket) do
  Phoenix.PubSub.subscribe(Lanpartyseating.PubSub, "station_update")
  {:ok, assign(socket, ...)}
end

def handle_info({:station_updated, station_id}, socket) do
  # Update socket assigns, re-render UI
  {:noreply, reload_stations(socket)}
end
```

## Key Algorithms

### Auto-Assignment Round-Robin

Located in: `lib/lanpartyseating/logic/autoassign_logic.ex`

```
1. Get last assigned station number (e.g., 45)
2. Get all available station IDs [1,2,3...70]
3. Split list at last assigned: [46,47...70] ++ [1,2,3...45]
4. Find first available station in rotated list
5. Create reservation for found station
6. Update last_assigned_station to found station
7. Broadcast update
```

This ensures even distribution across all stations over time.

### Station Availability Check

Located in: `lib/lanpartyseating/logic/station_logic.ex`

```
Station is available IF:
  - NOT is_closed (manual closure)
  - NOT is_broken (out of order)
  - NOT deleted_at (soft deleted)
  - NO overlapping reservations (check start_date/end_date ranges)
  - NO tournament locks for requested time period
```

## Configuration

### Environment Variables (Production)

**Database:**
- `DATABASE_URL` - PostgreSQL connection string

**Web:**
- `PHX_HOST` - Public hostname
- `PORT` - HTTP port (default: 4000)
- `SECRET_KEY_BASE` - Phoenix secret (required)

**Timezone:**
- `TZ=America/Toronto` - Application timezone (Montreal)
- `STORAGE_DIR=/tmp/tzdata` - Timezone data cache

**Observability:**
- `GRAFANA_ENABLE=1` - Enable Grafana integration
- `GRAFANA_HOST` - Grafana instance URL
- `GRAFANA_AUTH_TOKEN` - Grafana API token
- `GRAFANA_DATASOURCE_ID` - Prometheus datasource ID
- `OTEL_EXPORTER_OTLP_TRACES_HEADERS=x-honeycomb-team=<TOKEN>` - Honeycomb.io tracing

**OTP:**
- `RELEASE_COOKIE` - Erlang distribution cookie (for clustering)

### Development Configuration

All in `config/dev.exs`:
- Database: `lanpartyseating_dev` on localhost:5432
- User: `postgres` / Password: `postgres`
- Live reload enabled
- Code reloading enabled
- Watchers: tailwindcss, esbuild

## Testing

### Running Tests

```bash
mix test                    # Run all tests
mix test test/path_test.exs # Run specific test file
mix test --trace            # Run with detailed output
```

### Test Structure

- **Unit tests**: None for logic layer (needs improvement)
- **Controller tests**: Basic tests in `test/lanpartyseating_web/controllers/`
- **View tests**: Basic tests in `test/lanpartyseating_web/views/`
- **Integration tests**: Missing

**Note:** Test coverage is limited. When adding features, consider adding tests first.

## Common Development Tasks

### Add a New LiveView Page

1. Create LiveView module in `lib/lanpartyseating_web/live/`
2. Add route in `lib/lanpartyseating_web/router.ex`
3. Add to `:nav` live_session
4. Subscribe to relevant PubSub topics in `mount/3`
5. Implement event handlers in `handle_event/3`
6. Create HEEx template inline or in separate file

### Add a New Business Logic Feature

1. Create logic module in `lib/lanpartyseating/logic/`
2. Keep functions pure (no side effects in logic layer)
3. Use repository modules for data access
4. Broadcast PubSub events for UI updates
5. Consider adding background tasks for time-based actions

### Add a New Repository/Schema

1. Create migration: `mix ecto.gen.migration create_table_name`
2. Define schema in `lib/lanpartyseating/repositories/`
3. Add changeset validation
4. Implement CRUD functions
5. Run migration: `mix ecto.migrate`

### Debugging

**IEx REPL:**
```bash
iex -S mix phx.server        # Start server with REPL
```

Add breakpoint in code:
```elixir
require IEx
IEx.pry()                    # Execution pauses here
```

**VSCode Debugging:**
- Install ElixirLS extension
- Use launch configurations in `.vscode/launch.json`
- Set breakpoints in editor

**Live Dashboard:**
- Visit `http://localhost:4000/dashboard` (dev only)
- View processes, metrics, request logs

## Technology Stack Summary

### Backend
- **Elixir 1.16+** - Functional programming language on BEAM VM
- **Phoenix 1.7.6** - Web framework
- **Phoenix LiveView 0.20** - Real-time server-rendered UI
- **Ecto 3.10** - Database ORM and query builder
- **PostgreSQL** - Relational database

### Frontend
- **Alpine.js 3.13** - Lightweight reactive JavaScript
- **Tailwind CSS 3.3** - Utility-first CSS framework
- **DaisyUI 4.6** - Tailwind component library
- **esbuild 0.7** - JavaScript bundler

### Observability
- **OpenTelemetry** - Distributed tracing (Ecto, Phoenix, LiveView, Cowboy)
- **PromEx 1.8** - Prometheus metrics exporter
- **Telemetry** - Event metrics
- **Grafana** - Dashboard visualization
- **Honeycomb.io** - Trace analysis

### Infrastructure
- **Nix** - Reproducible development environment and builds
- **devenv** - Nix-based dev environment with PostgreSQL service
- **GitHub Actions** - CI/CD for container builds
- **OTP Releases** - Production deployment format

## Design Philosophy

1. **Server-side Rendering**: LiveView eliminates complex client-side state management
2. **Real-time by Default**: PubSub ensures all clients see updates instantly
3. **Event Context**: No authentication system; badge scanning provides identity
4. **Time-based Automation**: OTP tasks handle scheduled operations (expiration, tournament start/end)
5. **Observability First**: Comprehensive tracing and metrics from day one
6. **Reproducible Builds**: Nix ensures consistent development and production environments
7. **Bilingual Support**: French/English throughout UI (Gettext)

## Common Patterns

### Creating a Reservation
```elixir
# In logic layer
ReservationLogic.create_reservation(%{
  station_id: 1,
  badge: "ABC123",
  duration: 60,
  start_date: DateTime.utc_now()
})
# → Creates reservation
# → Calculates end_date (start_date + duration minutes)
# → Schedules expiration task
# → Broadcasts station_update event
```

### Broadcasting Updates
```elixir
Phoenix.PubSub.broadcast(
  Lanpartyseating.PubSub,
  "station_update",
  {:station_updated, station_id}
)
```

### Soft Deleting
```elixir
# All entities use soft delete pattern
ReservationRepo.update(reservation, %{deleted_at: DateTime.utc_now()})
# Queries automatically filter deleted_at IS NULL
```

### Background Task Creation
```elixir
# In logic layer after creating reservation
{:ok, _pid} = DynamicSupervisor.start_child(
  Lanpartyseating.ExpirationTaskSupervisor,
  {Lanpartyseating.ExpireReservation, [reservation.id, reservation.end_date]}
)
```

## Gotchas and Important Notes

1. **Timezone Handling**: All dates stored as UTC in database, converted to `America/Toronto` for display
2. **Soft Deletes**: Always check `deleted_at IS NULL` in queries
3. **Station Numbering**: Station numbers are not sequential; they're defined in station_layout table
4. **Tournament Locks**: Stations locked for tournaments cannot be reserved normally
5. **Round-Robin State**: `last_assigned_station` table has only one row (singleton pattern)
6. **No User Auth**: System assumes trusted environment; no password authentication
7. **Desktop Clients**: Use Phoenix Channels, separate from web UI LiveView sockets
8. **Task Restoration**: ExpirationKickstarter restarts all future tasks on app boot
9. **Grid Coordinates**: Station layout uses (x, y) grid system for visual display
10. **Bilingual UI**: All user-facing text should be in both French and English

## Deployment

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
```

### Database Setup

```bash
bin/server eval "Lanpartyseating.Release.migrate()"
bin/server eval "Lanpartyseating.Release.seed()"
```

## Useful Commands

```bash
# Development
mix phx.server              # Start dev server
mix phx.routes              # List all routes
mix ecto.reset              # Drop, create, migrate, seed DB
iex -S mix phx.server       # Start with IEx REPL

# Database
mix ecto.create             # Create database
mix ecto.migrate            # Run migrations
mix ecto.rollback           # Rollback last migration
mix ecto.gen.migration name # Generate new migration

# Code Quality
mix format                  # Format code
mix credo                   # Run linter
mix test                    # Run tests

# Production
mix assets.deploy           # Build and digest assets
mix release                 # Build OTP release

# Nix
nix develop                 # Enter dev shell
nix build                   # Build package
devenv up                   # Start services (PostgreSQL)
```

## File References for Common Tasks

**Routing**: `lib/lanpartyseating_web/router.ex:1`  
**Application Startup**: `lib/lanpartyseating/application.ex:1`  
**Database Schema**: `priv/repo/migrations/20240814023743_squash_migrations.exs:1`  
**Auto-Assignment**: `lib/lanpartyseating/logic/autoassign_logic.ex`  
**Reservation Management**: `lib/lanpartyseating/logic/reservation_logic.ex`  
**Station Availability**: `lib/lanpartyseating/logic/station_logic.ex`  
**Public Display**: `lib/lanpartyseating_web/live/display_live.ex:33`  
**Badge Scanning**: `lib/lanpartyseating_web/live/autoassign_live.ex:34`  

## Questions to Ask When Modifying Code

1. **Does this change affect station availability?** → Broadcast `station_update` event
2. **Does this involve time-based actions?** → Create/update background tasks
3. **Should this be real-time?** → Subscribe to PubSub in LiveView
4. **Is this a new entity?** → Add soft delete (`deleted_at`), create repository
5. **Does this need validation?** → Add changeset rules in repository
6. **Will this block other operations?** → Check for overlapping reservations/tournaments
7. **Is this user-facing text?** → Add to Gettext translations (FR/EN)
8. **Does this need observability?** → Add telemetry events

---

**Last Updated:** Tue Jan 13 2026  
**For Questions:** See README.md or examine code in referenced file locations above
