# Seeds for LAN Party Seating
#
# Run with: mix ecto.reset
#
# This file assumes a fresh database.

alias Lanpartyseating.Repo
alias Lanpartyseating.Setting
alias Lanpartyseating.StationLayout
alias Lanpartyseating.Station
alias Lanpartyseating.Badge
alias Lanpartyseating.Tournament
alias Lanpartyseating.TournamentReservation

# =============================================================================
# CONFIGURATION - Adjust these values for your event
# =============================================================================

# Grid dimensions (total stations = columns × rows)
station_columns = 10
station_rows = 7

# Sample data timing - days offset from today
# 0 = today, 1 = tomorrow, etc.
event_start_offset_days = 0

# =============================================================================
# SETTINGS
# =============================================================================

%Setting{}
|> Setting.changeset(%{
  row_padding: 2,
  column_padding: 1,
  horizontal_trailing: 1,
  vertical_trailing: 0,
})
|> Repo.insert!()

IO.puts("Created default settings")

# =============================================================================
# STATIONS
# =============================================================================

# Layout must be created before stations due to foreign key constraint
total_stations = station_columns * station_rows

for station_number <- 1..total_stations do
  %StationLayout{}
  |> StationLayout.changeset(%{
    station_number: station_number,
    x: rem(station_number - 1, station_columns),
    y: div(station_number - 1, station_columns),
  })
  |> Repo.insert!()
end

for station_number <- 1..total_stations do
  %Station{}
  |> Station.changeset(%{station_number: station_number})
  |> Repo.insert!()
end

IO.puts("Created #{total_stations} stations (#{station_columns} cols x #{station_rows} rows)")

# =============================================================================
# ADMIN USER
# =============================================================================

{:ok, admin} =
  Lanpartyseating.Accounts.create_user(%{
    name: "Admin",
    email: "admin@otakuthon.com",
    password: "change-me-on-first-login",
  })

Repo.update!(Ecto.Changeset.change(admin, confirmed_at: NaiveDateTime.utc_now(:second)))

IO.puts("Created admin user: admin@otakuthon.com (password: change-me-on-first-login)")

# =============================================================================
# ADMIN BADGE
# =============================================================================

Lanpartyseating.Accounts.create_admin_badge(%{
  badge_number: "ADMIN-001",
  label: "Emergency Admin / Admin d'urgence",
  enabled: true,
})

IO.puts("Created admin badge: ADMIN-001")

# =============================================================================
# SAMPLE BADGE
# =============================================================================

%Badge{}
|> Badge.changeset(%{uid: "1", serial_key: "1"})
|> Repo.insert!()

IO.puts("Created sample badge: 1")

# =============================================================================
# SAMPLE TOURNAMENTS
# =============================================================================

now = DateTime.utc_now() |> DateTime.truncate(:second)
event_base = DateTime.add(now, event_start_offset_days * 24 * 60 * 60, :second)

# Tournament 1: Starts in 2 hours, runs 3 hours
tournament1_start = DateTime.add(event_base, 2 * 60 * 60, :second)
tournament1_end = DateTime.add(tournament1_start, 3 * 60 * 60, :second)

tournament1 =
  %Tournament{}
  |> Tournament.changeset(%{
    name: "League of Legends",
    start_date: tournament1_start,
    end_date: tournament1_end,
  })
  |> Repo.insert!()

# Tournament 2: Tomorrow at 2pm, runs 3 hours
tomorrow_2pm =
  event_base
  |> DateTime.add(24 * 60 * 60, :second)
  |> Map.put(:hour, 14)
  |> Map.put(:minute, 0)
  |> Map.put(:second, 0)

tournament2_end = DateTime.add(tomorrow_2pm, 3 * 60 * 60, :second)

%Tournament{}
|> Tournament.changeset(%{
  name: "Valorant",
  start_date: tomorrow_2pm,
  end_date: tournament2_end,
})
|> Repo.insert!()

# Tournament 3: Day after tomorrow at 6pm, runs 2 hours
day_after_6pm =
  event_base
  |> DateTime.add(2 * 24 * 60 * 60, :second)
  |> Map.put(:hour, 18)
  |> Map.put(:minute, 0)
  |> Map.put(:second, 0)

tournament3_end = DateTime.add(day_after_6pm, 2 * 60 * 60, :second)

%Tournament{}
|> Tournament.changeset(%{
  name: "Rocket League",
  start_date: day_after_6pm,
  end_date: tournament3_end,
})
|> Repo.insert!()

IO.puts("Created 3 sample tournaments")

# =============================================================================
# TOURNAMENT RESERVATIONS
# =============================================================================

# Lock stations 1-10 for the first tournament (League of Legends)
for station_number <- 1..10 do
  %TournamentReservation{}
  |> TournamentReservation.changeset(%{
    station_id: station_number,
    tournament_id: tournament1.id,
  })
  |> Repo.insert!()
end

IO.puts("Locked stations 1-10 for League of Legends tournament")
