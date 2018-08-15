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

Lanpartyseating.Repo.insert!(%Lanpartyseating.Reservation{
  UID: "E0040150BD357501",
  row: 2,
  column: 1
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Reservation{
  UID: "E0040150BD357501",
  row: 3,
  column: 4
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Reservation{
  UID: "E0040150BD357501",
  row: 1,
  column: 3
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Reservation{
  UID: "E0040150BD357501",
  row: 2,
  column: 6
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Reservation{
  UID: "E0040150BD357501",
  row: 9,
  column: 1
})

# Far away reservations

Lanpartyseating.Repo.insert!(%Lanpartyseating.Reservation{
  UID: "E0040150BD357501",
  row: 99,
  column: 99
})

Lanpartyseating.Repo.insert!(%Lanpartyseating.Reservation{
  UID: "E0040150BD357501",
  row: 62,
  column: 130
})
