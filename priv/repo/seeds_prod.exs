# Production Seeds for LAN Party Seating
#
# Run with: bin/lanpartyseating eval "Lanpartyseating.Release.seed()"
#
# This file creates only the minimal required data for production.
# For development with sample data, use seeds.exs via `mix ecto.reset`.

alias Lanpartyseating.Repo
alias Lanpartyseating.Setting
alias Lanpartyseating.StationLayout
alias Lanpartyseating.Station
alias Lanpartyseating.Accounts.User

# =============================================================================
# CONFIGURATION
# =============================================================================

station_columns = 10
station_rows = 7

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

admin |> User.confirm_changeset() |> Repo.update!()

IO.puts("Created admin user: admin@otakuthon.com (password: change-me-on-first-login)")
