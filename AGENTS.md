# LAN Party Seating - Agent Guide

## Project Overview

Real-time web application for managing gaming station reservations at LAN party events. Handles badge scanning, auto-assignment, tournaments, and live station availability displays.

**Stack:** Elixir 1.16+ / Phoenix 1.7 / LiveView / Alpine.js / Tailwind CSS / DaisyUI / PostgreSQL

## Quick Start

```bash
direnv allow                               # Setup nix environment
devenv up                                  # Terminal 1: Start PostgreSQL (keep running)
mix deps.get                               # Install Elixir dependencies
cd assets && yarn install && cd ..         # Install Node.js dependencies
mix ecto.reset                             # Create, migrate, seed database
mix phx.server                             # Start server at localhost:4000
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Web Layer (LiveView, Controllers, Channels)           │
│  lib/lanpartyseating_web/                               │
└─────────────────────┬───────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│  Business Logic Layer (Pure Functions)                  │
│  lib/lanpartyseating/logic/                             │
└─────────────────────┬───────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│  Data Access Layer (Repository Pattern)                 │
│  lib/lanpartyseating/repositories/                      │
└─────────────────────┬───────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│  Database (PostgreSQL via Ecto)                         │
└─────────────────────────────────────────────────────────┘
```

### Key Decisions

- **Repository Pattern**: All database access through dedicated repository modules
- **Business Logic Separation**: Pure functions in `logic/` modules
- **PubSub Broadcasting**: Real-time updates across all connected clients
- **OTP Tasks**: GenServer-based expiration tasks for time-based reservations
- **Soft Deletes**: All entities have `deleted_at` timestamp
- **No Authentication**: Badge-based identity (trusted event environment)

## Directory Structure

```
lib/
├── lanpartyseating/
│   ├── logic/                         # Business logic (PURE FUNCTIONS)
│   │   ├── autoassign_logic.ex        # Station auto-assignment algorithm
│   │   ├── reservation_logic.ex       # Reservation CRUD
│   │   ├── station_logic.ex           # Station availability
│   │   └── tournaments_logic.ex       # Tournament scheduling
│   │
│   ├── repositories/                  # Data access (ECTO SCHEMAS)
│   │   ├── reservation_repo.ex
│   │   ├── station_repo.ex
│   │   ├── tournament_repo.ex
│   │   └── ...
│   │
│   └── tasks/                         # Background tasks (GENSERVER)
│       ├── expire_reservation.ex
│       └── expire_tournament.ex
│
└── lanpartyseating_web/
    ├── router.ex                      # Route definitions
    │
    ├── components/                    # Reusable components
    │   ├── ui.ex                      # Shared UI components
    │   ├── icons.ex
    │   ├── layouts.ex
    │   └── *_modal.ex                 # Station modal components
    │
    └── live/                          # LiveView pages
        ├── display_live.ex            # Public display (station map)
        ├── autoassign_live.ex         # Badge scanning
        ├── selfsign_live.ex           # Self-service signup
        ├── cancellation_live.ex       # Cancel reservations
        ├── tournaments_live.ex        # Tournament management
        ├── settings_live.ex           # Layout settings
        ├── logs_live.ex               # Activity logs
        └── manhole_live.ex            # Debug console
```

## Development Best Practices

### UI Components

**Use shared components from `lib/lanpartyseating_web/components/ui.ex`:**

| Component | Purpose |
|-----------|---------|
| `station_legend` | Status color legend (available/occupied/broken/tournament) |
| `station_grid` | Station grid with table grouping |
| `station_button` | Styled station button with countdown timer |
| `countdown` | Alpine.js countdown (MM:SS format) |
| `countdown_long` | Countdown with hours support |
| `page_header` | Consistent page headers with optional trailing slot |
| `admin_section` | Admin page sections with bordered heading |
| `labeled_input` | Form inputs with horizontal labels |
| `data_table` | Styled data tables |
| `modal` | DaisyUI modal dialogs |

**When to create components:**
- Extract to `ui.ex` when a pattern appears in 2+ places
- Same HTML structure with different data
- Complex Alpine.js behavior (countdowns, modals)

**DaisyUI over raw Tailwind:**
- Use `btn btn-success` not `bg-green-500 text-white px-4 py-2`
- Use `alert alert-error` not custom error styling
- Use `modal modal-box` for dialogs

### Layer Separation

**Logic Layer** (`lib/lanpartyseating/logic/`):
- Pure functions, no side effects
- Call repository modules for data access
- Broadcast PubSub events for UI updates
- Return `{:ok, result}` or `{:error, reason}` tuples

**Repository Layer** (`lib/lanpartyseating/repositories/`):
- Ecto schemas and changesets
- CRUD functions: `get/1`, `list/0`, `create/1`, `update/2`, `delete/1`
- Queries filter `deleted_at IS NULL` by default

**Web Layer** (`lib/lanpartyseating_web/`):
- LiveView pages handle UI and user interactions
- Subscribe to PubSub in `mount/3`
- Handle events in `handle_event/3`
- Handle broadcasts in `handle_info/2`

### Real-time Updates

Pattern for broadcasting changes:

```elixir
# In logic layer - broadcast after state change
Phoenix.PubSub.broadcast(Lanpartyseating.PubSub, "station_update", {:station_updated, station_id})

# In LiveView mount - subscribe to topic
Phoenix.PubSub.subscribe(Lanpartyseating.PubSub, "station_update")

# In LiveView handle_info - react to broadcast
def handle_info({:station_updated, _station_id}, socket), do: {:noreply, reload_stations(socket)}
```

Topics: `"station_update"`, `"tournament_update"`

### Bilingual Requirement

All user-facing text must be in both French and English. Use inline bilingual text:
- "Available / Disponible"
- "Reserve / Réserver"

## Common Tasks

### Add a New LiveView Page

1. Create module in `lib/lanpartyseating_web/live/`
2. Add route in `router.ex` under `:nav` live_session
3. Subscribe to PubSub topics in `mount/3`
4. Implement `handle_event/3` for user interactions
5. Use shared components from `ui.ex`

### Add Business Logic

1. Create module in `lib/lanpartyseating/logic/`
2. Keep functions pure (no side effects)
3. Use repository modules for data access
4. Broadcast PubSub events for UI updates

### Add Database Entity

1. Generate migration: `mix ecto.gen.migration create_table_name`
2. Define schema in `lib/lanpartyseating/repositories/`
3. Add `deleted_at` field for soft deletes
4. Run migration: `mix ecto.migrate`

## Gotchas

1. **Timezone**: Dates stored as UTC, displayed in `America/Toronto`
2. **Soft Deletes**: Always filter `deleted_at IS NULL` in queries
3. **Station Numbers**: Not sequential; defined in `station_layout` table
4. **Tournament Locks**: Stations locked for tournaments cannot be reserved
5. **Round-Robin State**: `last_assigned_station` table is a singleton (one row)
6. **No Auth**: System assumes trusted environment; badge scanning provides identity
7. **Desktop Clients**: Use Phoenix Channels, separate from LiveView sockets
8. **Task Restoration**: `ExpirationKickstarter` restarts pending tasks on app boot
9. **Grid Coordinates**: Station layout uses (x, y) grid system
10. **Bilingual**: All user-facing text needs French + English


<!-- phoenix-gen-auth-start -->
## Authentication

- **Always** handle authentication flow at the router level with proper redirects
- **Always** be mindful of where to place routes. `phx.gen.auth` creates multiple router plugs:
  - A plug `:fetch_current_scope_for_user` that is included in the default browser pipeline
  - A plug `:require_authenticated_user` that redirects to the log in page when the user is not authenticated
  - In both cases, a `@current_scope` is assigned to the Plug connection
  - A plug `redirect_if_user_is_authenticated` that redirects to a default path in case the user is authenticated - useful for a registration page that should only be shown to unauthenticated users
- **Always let the user know in which router scopes and pipeline you are placing the route, AND SAY WHY**
- `phx.gen.auth` assigns the `current_scope` assign - it **does not assign a `current_user` assign**
- Always pass the assign `current_scope` to context modules as first argument. When performing queries, use `current_scope.user` to filter the query results
- To derive/access `current_user` in templates, **always use the `@current_scope.user`**, never use **`@current_user`** in templates
- Anytime you hit `current_scope` errors or the logged in session isn't displaying the right content, **always double check the router and ensure you are using the correct plug as described below**

### Routes that require authentication

Controller routes must be placed in a scope that sets the `:require_authenticated_user` plug:

    scope "/", AppWeb do
      pipe_through [:browser, :require_authenticated_user]

      get "/", MyControllerThatRequiresAuth, :index
    end

### Routes that work with or without authentication

Controllers automatically have the `current_scope` available if they use the `:browser` pipeline.

<!-- phoenix-gen-auth-end -->