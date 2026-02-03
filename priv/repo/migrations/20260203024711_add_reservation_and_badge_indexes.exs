defmodule Lanpartyseating.Repo.Migrations.AddReservationAndBadgeIndexes do
  use Ecto.Migration

  def change do
    # Partial index for finding active reservations by badge (sign-out functionality)
    create index(:reservations, [:badge], where: "deleted_at IS NULL", name: :reservations_badge_active_idx)

    # Partial index for finding active reservations by station (cancel/extend)
    create index(:reservations, [:station_id], where: "deleted_at IS NULL", name: :reservations_station_id_active_idx)

    # Index for paginated badge listing with ORDER BY inserted_at DESC, id DESC
    create index(:badges, [desc: :inserted_at, desc: :id], name: :badges_inserted_at_id_idx)
  end
end
