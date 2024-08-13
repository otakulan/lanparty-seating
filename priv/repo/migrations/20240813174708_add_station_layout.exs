defmodule Lanpartyseating.Repo.Migrations.AddStationLayout do
  use Ecto.Migration

  def change do
    create table(:station_layout, primary_key: false) do
      add(:station_id, :integer, primary_key: true)
      add(:x, :integer, null: false)
      add(:y, :integer, null: false)
    end

    create unique_index(:station_layout, [:x, :y])
  end
end
