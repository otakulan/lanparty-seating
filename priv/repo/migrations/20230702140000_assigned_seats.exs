defmodule Lanpartyseating.Repo.Migrations.AddAssignedSeatsTables do
  use Ecto.Migration

  def change do
    create table(:last_assigned_seat) do
      # ID of the last assigned gaming station
      add :last_assigned_seat, :integer
      timestamps()
    end

    create table(:stations_status) do
      # Populate with all the IDs of the gaming stations. Set their assignation to true or false.
      # We can quickly retrive them to see which stations are occupied (e.g. to show all of them on a page)
      # or to quickly find the next available seat to assign a new participant.
      # A station can be set out of order if it stops working during the event.
      add :station_id, :integer
      add :is_assigned, :boolean
      add :is_out_of_order, :boolean
      timestamps()
    end
  end
end
