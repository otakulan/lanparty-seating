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
  start_date: ~U[2022-08-05 11:30:00Z],
  end_date: ~U[2022-08-05 14:30:00Z],
  name: "League of Legends"
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-05 15:30:00Z],
  end_date: ~U[2022-08-05 18:30:00Z],
  name: "Rainbow Six Siege"
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-05 20:00:00Z],
  end_date: ~U[2022-08-05 23:00:00Z],
  name: "Valorant"
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-06 11:30:00Z],
  end_date: ~U[2022-08-06 14:30:00Z],
  name: "Rainbow Six Siege"
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-06 15:30:00Z],
  end_date: ~U[2022-08-06 18:30:00Z],
  name: "League of Legends"
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-06 20:00:00Z],
  end_date: ~U[2022-08-06 23:00:00Z],
  name: "Valorant"
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-08-07 11:30:00Z],
  end_date: ~U[2022-08-07 14:30:00Z],
  name: "League of Legends"
})

test = Lanpartyseating.Repo.insert!(%Lanpartyseating.Tournament{
  start_date: ~U[2022-07-31 22:00:00Z],
  end_date: ~U[2022-08-07 14:30:00Z],
  name: "Test"
})

for val <- 1..225, do:
Lanpartyseating.Repo.insert!(%Lanpartyseating.Station{
  station_number: val,
  display_order: val,
  is_closed: false
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.TournamentReservation{
  station_id: 1,
  tournament_id: 8,
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Setting{
  rows: 2,
  columns: 4,
  row_padding: 1,
  column_padding: 1,
  horizontal_trailing: 0,
  vertical_trailing: 0
})
