defmodule Lanpartyseating.Repo.Migrations.RemoveUnusedStationColumns do
  use Ecto.Migration

  def change do
    # Remove unused is_closed column from stations table
    # This field was never used - station broken status is tracked via stations_status.is_broken
    alter table(:stations) do
      remove :is_closed, :boolean, default: false
    end

    # Remove unused is_assigned column from stations_status table
    # This field was defined but never read or written in business logic
    alter table(:stations_status) do
      remove :is_assigned, :boolean, default: false
    end
  end
end
