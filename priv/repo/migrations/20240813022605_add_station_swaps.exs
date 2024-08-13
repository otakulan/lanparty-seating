defmodule Lanpartyseating.Repo.Migrations.AddStationSwaps do
  use Ecto.Migration

  def change do
    # TODO: foreign key
    create table(:station_swaps) do
      add(:this, :integer)
      add(:that, :integer)
      timestamps()
    end
  end
end
