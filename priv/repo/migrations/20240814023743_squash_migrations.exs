defmodule Lanpartyseating.Repo.Migrations.SquashMigrations do
  use Ecto.Migration

  def change do
    create table(:reservations) do
      add :duration, :integer
      add :badge, :string
      add :incident, :string
      add :deleted_at, :utc_datetime
      add :station_id, :id
      add :start_date, :utc_datetime
      add :end_date, :utc_datetime
      timestamps()
    end

    create table(:settings) do
      #add :rows, :integer
      #add :columns, :integer
      add :station_count, :integer
      add :row_padding, :integer
      add :column_padding, :integer
      add :horizontal_trailing, :integer
      add :is_diagonally_mirrored, :integer
      add :vertical_trailing, :integer
      add :deleted_at, :utc_datetime
      timestamps()
    end

    create table(:station_layout, primary_key: false) do
      add(:station_number, :integer, primary_key: true)
      add(:x, :integer, null: false)
      add(:y, :integer, null: false)
    end
    create unique_index(:station_layout, [:x, :y])

    create table(:stations, primary_key: false) do
      # Don't allow a station to exist if we don't know where it belongs
      add :station_number, references(:station_layout, column: :station_number), primary_key: true
      add :is_closed, :boolean
      add :deleted_at, :utc_datetime
      timestamps()
    end

    create table(:tournaments) do
      add :start_date, :utc_datetime
      add :end_date, :utc_datetime
      add :name, :string
      add :deleted_at, :utc_datetime
      timestamps()
    end

    create table(:tournament_reservations) do
      add :station_id, references(:stations, column: :station_number, on_delete: :delete_all)
      add :tournament_id, references(:tournaments, on_delete: :delete_all)
      add :deleted_at, :utc_datetime
      timestamps()
    end

    create table(:last_assigned_station) do
      # ID of the last assigned gaming station
      add(:last_assigned_station, :integer)
      add(:last_assigned_station_date, :utc_datetime)
      timestamps()
    end

    create table(:stations_status) do
      # Populate with all the IDs of the gaming stations. Set their assignation to true or false.
      # We can quickly retrive them to see which stations are occupied (e.g. to show all of them on a page)
      # or to quickly find the next available seat to assign a new participant.
      # A station can be set out of order if it stops working during the event.
      add(:station_id, :integer)
      add(:is_assigned, :boolean)
      add(:is_out_of_order, :boolean)
      timestamps()
    end

    create table(:badges) do
      add(:serial_key, :string)
      add(:uid, :string)
      add(:is_banned, :boolean, default: false)
      timestamps()
    end

  end
end
