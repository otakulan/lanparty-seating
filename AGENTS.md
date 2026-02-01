# LAN Party Seating - Agent Guide

> **IMPORTANT**: Keep this document in sync with the codebase. Update when adding, 
> removing, or refactoring modules.

## Project Overview

Real-time web application for managing gaming station reservations at LAN party events. Handles badge scanning, tournaments, and live station availability displays.

**Stack:** Elixir 1.16+ / Phoenix 1.7 / LiveView / Alpine.js / Tailwind CSS / DaisyUI / PostgreSQL

## Quick Start

```bash
direnv allow                               # Setup nix environment
devenv up                                  # Terminal 1: Start PostgreSQL (keep running)
mix deps.get                               # Install Elixir dependencies
mix usage_rules.sync AGENTS.md --all --link-to-folder deps  # Sync LLM docs from deps
cd assets && yarn install && cd ..         # Install Node.js dependencies
mix ecto.reset                             # Create, migrate, seed database
mix phx.server                             # Start server at localhost:4000
```

## Architecture

```
Web Layer (LiveView, Controllers, Channels) → lib/lanpartyseating_web/
    ↓
Business Logic Layer (Pure Functions) → lib/lanpartyseating/logic/
    ↓
Data Access Layer (Ecto Schemas) → lib/lanpartyseating/repositories/
    ↓
Database (PostgreSQL via Ecto)
```

### Key Decisions

- **Ecto Schemas**: Schema definitions in `repositories/` (logic modules access `Repo` directly)
- **Business Logic Separation**: Pure functions in `logic/` modules
- **PubSub Broadcasting**: Real-time updates across all connected clients
- **OTP Tasks**: GenServer-based expiration tasks for time-based reservations
- **Soft Deletes**: All entities have `deleted_at` timestamp
- **No Authentication**: Badge-based identity (trusted event environment)

## Directory Structure

- `lib/lanpartyseating/logic/` - Business logic modules (badges, maintenance, reservation, scanner, settings, station, tournaments)
- `lib/lanpartyseating/repositories/` - Ecto schema definitions (not a repository pattern - just schemas, badge_scanner, scanner_wifi_config)
- `lib/lanpartyseating/tasks/` - GenServer background tasks (expiration_kickstarter, expire_reservation, expire_tournament, start_tournament)
- `lib/lanpartyseating/accounts/` - User authentication (phx.gen.auth generated)
- `lib/lanpartyseating_web/live/` - LiveView pages (admin_badges, admin_users, display, logs, maintenance, profile, settings, stations, tournaments)
- `lib/lanpartyseating_web/components/` - Reusable components (display_modal, icons, layouts, nav, station_modal, tournament_modal, ui)
- `lib/lanpartyseating_web/controllers/api/v1/` - REST API controllers (reservation_controller for scanner badge cancellation)
- `lib/lanpartyseating_web/plugs/` - Custom Plug modules (scanner_auth for bearer token authentication)

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

### Elixir Code Style

**Write assertive, not defensive code:**
- Pattern match on what you expect, let it crash if wrong
- Avoid Ruby-style `if/then/else` chains and excessive nil-checking
- Use `with` for chaining fallible operations, not nested `case`
- Process restarts in a good state - trust the supervision tree

**AI agents tend to write defensive/imperative code by default.** Be strict about enforcing idiomatic Elixir patterns. The codebase should use pattern matching on function heads, guard clauses, and `{:ok, _}`/`{:error, _}` tuples consistently.

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

## External Badge Scanner Integration

ESP32-based exit badge scanners allow attendees to cancel reservations at exit points.

**Hardware Firmware:** [otakulan/lanparty-seating-badge-reader](https://github.com/otakulan/lanparty-seating-badge-reader)

### Server-Side Components

| File | Purpose |
|------|---------|
| `lib/lanpartyseating/logic/scanner_logic.ex` | Scanner CRUD, WiFi config, token management |
| `lib/lanpartyseating/repositories/badge_scanner.ex` | Scanner schema |
| `lib/lanpartyseating/repositories/scanner_wifi_config.ex` | WiFi config schema (singleton) |
| `lib/lanpartyseating_web/controllers/api/v1/reservation_controller.ex` | `POST /api/v1/reservations/cancel` |
| `lib/lanpartyseating_web/plugs/scanner_auth.ex` | Bearer token authentication |
| `lib/lanpartyseating_web/live/settings/scanners_live.ex` | Scanner management UI with BLE provisioning |
| `assets/js/hooks/bluetooth_provisioning.js` | WebBluetooth LiveView hook |

### API Endpoint

`POST /api/v1/reservations/cancel`
- **Auth:** Bearer token (`Authorization: Bearer lpss_...`)
- **Body:** `{"badge_uid": "..."}`
- **Returns:** 200 (cancelled), 404 (no reservation), 401 (invalid token)

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
11. **OTP/Async Debugging**: AI agents struggle with OTP, Task, and async issues. They don't understand process lifecycles, the actor model, or GenServer interactions. Step in early when debugging concurrency.
12. **Ecto Sandbox Isolation**: Each test runs in a transaction that rolls back. AI may query dev DB thinking it's test DB. Tests can't see each other's data due to transaction isolation.
13. **Scanner Tokens**: Tokens are `lpss_` prefixed, stored as bcrypt hash. Only the prefix is visible in UI for identification.
14. **HTTPS for WebBluetooth**: Dev provisioning requires HTTPS on port 4001. Certs must be generated with OpenSSL directly (not `mix phx.gen.cert`) due to OTP 28 + Chrome SSL compatibility issues.


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
<!-- usage-rules-start -->
<!-- usage-rules-header -->
# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below.
Before attempting to use any of these packages or to discover if you should use them, review their
usage rules to understand the correct patterns, conventions, and best practices.
<!-- usage-rules-header-end -->

<!-- usage_rules-start -->
## usage_rules usage
_A dev tool for Elixir projects to gather LLM usage rules from dependencies_

[usage_rules usage rules](deps/usage_rules/usage-rules.md)
<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
[usage_rules:elixir usage rules](deps/usage_rules/usage-rules/elixir.md)
<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
[usage_rules:otp usage rules](deps/usage_rules/usage-rules/otp.md)
<!-- usage_rules:otp-end -->
<!-- phoenix:ecto-start -->
## phoenix:ecto usage
[phoenix:ecto usage rules](deps/phoenix/usage-rules/ecto.md)
<!-- phoenix:ecto-end -->
<!-- phoenix:elixir-start -->
## phoenix:elixir usage
[phoenix:elixir usage rules](deps/phoenix/usage-rules/elixir.md)
<!-- phoenix:elixir-end -->
<!-- phoenix:html-start -->
## phoenix:html usage
[phoenix:html usage rules](deps/phoenix/usage-rules/html.md)
<!-- phoenix:html-end -->
<!-- phoenix:liveview-start -->
## phoenix:liveview usage
[phoenix:liveview usage rules](deps/phoenix/usage-rules/liveview.md)
<!-- phoenix:liveview-end -->
<!-- phoenix:phoenix-start -->
## phoenix:phoenix usage
[phoenix:phoenix usage rules](deps/phoenix/usage-rules/phoenix.md)
<!-- phoenix:phoenix-end -->
<!-- usage-rules-end -->
