defmodule Lanpartyseating.Repo.Migrations.UpdateSeatMapsSlugUniqueConstraint do
  use Ecto.Migration

  def up do
    drop_if_exists index(:seat_maps, [:slug], name: :seat_maps_slug_index)
    create unique_index(:seat_maps, [:deleted_at, :slug], where: "deleted_at IS NULL", name: :seat_maps_deleted_at_slug_index)
  end

  def down do
    drop_if_exists index(:seat_maps, [:deleted_at, :slug], name: :seat_maps_deleted_at_slug_index)
    create unique_index(:seat_maps, [:slug], where: "deleted_at IS NULL", name: :seat_maps_slug_index)
  end
end
