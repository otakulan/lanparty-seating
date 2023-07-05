defmodule Lanpartyseating.Repo.Migrations.RemoveStationPositions do
  use Ecto.Migration

  def change do
    drop table(:station_positions)
  end
end
