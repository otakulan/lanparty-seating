defmodule Lanpartyseating.Repo.Migrations.AddStationPositionsTable do
  use Ecto.Migration

  def change do
    create table(:station_positions) do
      add :row, :integer
      add :column, :integer
    end
  end
end
