defmodule Lanpartyseating.Repo.Migrations.AddSeatPickingEnabledToSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :seat_picking_enabled_in_kiosk, :boolean, default: false
    end
  end
end
