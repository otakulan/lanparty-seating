# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Lanpartyseating.Repo.insert!(%Lanpartyseating.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# A few regular reservations

# Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
#   start_date: ~U[2023-08-11 17:30:00Z],
#   end_date: ~U[2023-08-11 20:30:00Z],
#   name: "League of Legends"
# })

# Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
#   start_date: ~U[2023-08-12 17:30:00Z],
#   end_date: ~U[2023-08-12 20:30:00Z],
#   name: "League of Legends"
# })

# Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
#   start_date: ~U[2023-08-13 17:30:00Z],
#   end_date: ~U[2023-08-13 20:30:00Z],
#   name: "League of Legends"
# })

# Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
#   start_date: ~U[2023-08-11 22:30:00Z],
#   end_date: ~U[2023-08-12 01:30:00Z],
#   name: "Rainbow Six Siege"
# })

# Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
#   start_date: ~U[2023-08-12 22:30:00Z],
#   end_date: ~U[2023-08-13 01:30:00Z],
#   name: "Rainbow Six Siege"
# })

# for val <- 1..225, do:
# Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
#   station_id: val,
#   tournament_id: 1,
# })

# for val <- 1..225, do:
# Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
#   station_id: val,
#   tournament_id: 2,
# })

# for val <- 1..225, do:
# Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
#   station_id: val,
#   tournament_id: 3,
# })

# for val <- 1..225, do:
# Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
#   station_id: val,
#   tournament_id: 4,
# })

# for val <- 1..225, do:
# Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
#   station_id: val,
#   tournament_id: 5,
# })

# Create only data required in this table: The last assigned seat ID.
Lanpartyseating.Repo.insert!(%Lanpartyseating.LastAssignedSeat{
  last_assigned_station: 0,
  last_assigned_station_date: ~U[2022-08-05 15:30:00Z]
})

# Create IDs in the Station Status table for all the stations
for val <- 1..225 do
      Lanpartyseating.Repo.insert!(%Lanpartyseating.StationStatus{
        station_id: val,
        is_assigned: false,
        is_out_of_order: false
      })
      Lanpartyseating.Repo.insert!(%Lanpartyseating.StationLayout{
        station_number: val,
        x: rem(val - 1, 7),
        y: div(val - 1, 7)
    })
end

for val <- 1..225,
    do:
      Lanpartyseating.Repo.insert!(%Lanpartyseating.Station{
        station_number: val,
        is_closed: false
      })

Lanpartyseating.Repo.insert!(%Lanpartyseating.Setting{
  station_count: 70,
  row_padding: 2,
  column_padding: 1,
  is_diagonally_mirrored: 1,
  horizontal_trailing: 1,
  vertical_trailing: 0
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Badge{
  uid: "1",
  serial_key: "1",
  is_banned: false
})
