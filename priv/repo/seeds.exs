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

# NOTE: The following seed data uses legacy module names that no longer exist.
# Database is now seeded via migrations. These are commented out for reference.
#
# # Create only data required in this table: The last assigned seat ID.
# Lanpartyseating.Repo.insert!(%Lanpartyseating.LastAssignedSeat{
#   last_assigned_station: 0,
#   last_assigned_station_date: ~U[2022-08-05 15:30:00Z],
# })
#
# # Default layout which closely matches what we had for 2024
# for val <- 1..70 do
#   Lanpartyseating.Repo.insert!(%Lanpartyseating.StationLayout{
#     station_number: val,
#     x: div(val - 1, 10),
#     y: rem(val - 1, 10),
#   })
# end
#
# # In 2024 we had 70 PCs
# for val <- 1..70,
#     do:
#       Lanpartyseating.Repo.insert!(%Lanpartyseating.Station{
#         station_number: val,
#       })
#
# Lanpartyseating.Repo.insert!(%Lanpartyseating.Setting{
#   row_padding: 2,
#   column_padding: 1,
#   horizontal_trailing: 1,
#   vertical_trailing: 0,
# })
#
# Lanpartyseating.Repo.insert!(%Lanpartyseating.Badge{
#   uid: "1",
#   serial_key: "1",
#   is_banned: false,
# })

# Initial admin user (change password on first login!)
# Email: admin@otakuthon.com
# Password: change-me-on-first-login
case Lanpartyseating.Accounts.get_user_by_email("admin@otakuthon.com") do
  nil ->
    Lanpartyseating.Accounts.create_user(%{
      email: "admin@otakuthon.com",
      password: "change-me-on-first-login",
    })
    |> case do
      {:ok, user} ->
        IO.puts("Created initial admin user: admin@otakuthon.com")
        # Mark user as confirmed
        Lanpartyseating.Repo.update!(Ecto.Changeset.change(user, confirmed_at: NaiveDateTime.utc_now(:second)))

      {:error, changeset} ->
        IO.puts("Failed to create admin user: #{inspect(changeset.errors)}")
    end

  _user ->
    IO.puts("Admin user already exists: admin@otakuthon.com")
end

# Sample admin badge for testing (disabled by default in production)
# Badge number: ADMIN-001
case Lanpartyseating.Repo.get_by(Lanpartyseating.Accounts.AdminBadge, badge_number: "ADMIN-001") do
  nil ->
    Lanpartyseating.Repo.insert!(%Lanpartyseating.Accounts.AdminBadge{
      badge_number: "ADMIN-001",
      label: "Emergency Admin / Admin d'urgence",
      enabled: true,
    })

    IO.puts("Created sample admin badge: ADMIN-001")

  _badge ->
    IO.puts("Admin badge already exists: ADMIN-001")
end
