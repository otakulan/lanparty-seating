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

Lanpartyseating.Repo.insert!(%Lanpartyseating.Station{
  station_number: 1,
  display_order: 1,
  is_closed: false
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Station{
  station_number: 2,
  display_order: 2,
  is_closed: false
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Station{
  station_number: 3,
  display_order: 3,
  is_closed: false
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Station{
  station_number: 4,
  display_order: 4,
  is_closed: false
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Station{
  station_number: 5,
  display_order: 5,
  is_closed: false
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Station{
  station_number: 6,
  display_order: 6,
  is_closed: false
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Station{
  station_number: 7,
  display_order: 7,
  is_closed: false
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Station{
  station_number: 8,
  display_order: 8,
  is_closed: false
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Setting{
  rows: 2,
  columns: 4,
  row_padding: 0,
  column_padding: 0,
  horizontal_trailing: 0,
  vertical_trailing: 0
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Reservation{
  badge: "xxx111",
  station_id: 1
})
