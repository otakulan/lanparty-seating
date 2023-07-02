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

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-05 15:30:00Z],
  end_date: ~U[2022-08-05 18:30:00Z],
  name: "League of Legends"
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-05 19:30:00Z],
  end_date: ~U[2022-08-05 22:30:00Z],
  name: "Rainbow Six Siege"
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-06 00:00:00Z],
  end_date: ~U[2022-08-06 03:00:00Z],
  name: "Valorant"
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-06 15:30:00Z],
  end_date: ~U[2022-08-06 18:30:00Z],
  name: "Rainbow Six Siege"
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-06 19:30:00Z],
  end_date: ~U[2022-08-06 22:30:00Z],
  name: "League of Legends"
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-07 00:00:00Z],
  end_date: ~U[2022-08-07 03:00:00Z],
  name: "Valorant"
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-07 15:30:00Z],
  end_date: ~U[2022-08-07 18:30:00Z],
  name: "League of Legends"
})

test = Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-07-31 22:00:00Z],
  end_date: ~U[2022-08-04 12:45:00Z],
  name: "Test"
})

for val <- 1..225, do:
Lanpartyseating.Repo.insert!(%Lanpartyseating.Station{
  station_number: val,
  display_order: val,
  is_closed: false
})

for val <- 1..225, do:
Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
  station_id: val,
  tournament_id: 1,
})

for val <- 1..225, do:
Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
  station_id: val,
  tournament_id: 2,
})

for val <- 1..225, do:
Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
  station_id: val,
  tournament_id: 3,
})

for val <- 1..225, do:
Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
  station_id: val,
  tournament_id: 4,
})

for val <- 1..225, do:
Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
  station_id: val,
  tournament_id: 5,
})

for val <- 1..225, do:
Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
  station_id: val,
  tournament_id: 6,
})

for val <- 1..225, do:
Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
  station_id: val,
  tournament_id: 7,
})

for val <- 1..225, do:
Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
  station_id: val,
  tournament_id: 8,
})

# Create only data required in this table: The last assigned seat ID.
Lanpartyseating.Repo.insert!(%Lanpartyseating.LastAssignedSeat{
  last_assigned_seat: -1,
  last_assigned_seat_date: ~U[2022-08-05 15:30:00Z]
})

# Create IDs in the Station Status table for all the stations
for val <- 1..225, do:
Lanpartyseating.Repo.insert!(%Lanpartyseating.StationStatus{
  station_id: val,
  is_assigned: false,
  is_out_of_order: false
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Setting{
  rows: 4,
  columns: 10,
  row_padding: 2,
  column_padding: 1,
  is_diagonally_mirrored: 1,
  horizontal_trailing: 1,
  vertical_trailing: 0
})
