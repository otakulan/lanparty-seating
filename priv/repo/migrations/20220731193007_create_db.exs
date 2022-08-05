defmodule Lanpartyseating.Repo.Migrations.CreateDb do
  use Ecto.Migration

  def change do
    create table(:reservations) do
      add :duration, :integer
      add :badge, :string
      add :incident, :string
      add :deleted_at, :utc_datetime
      add :station_id, :id
      timestamps()
    end

    create table(:settings) do
      add :rows, :integer
      add :columns, :integer
      add :row_padding, :integer
      add :column_padding, :integer
      add :horizontal_trailing, :integer
      add :is_diagonally_mirrored, :integer
      add :vertical_trailing, :integer
      add :deleted_at, :utc_datetime
      timestamps()
    end

    create table(:tournament_reservations) do
      add :station_id, :integer
      add :tournament_id, :integer
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

    create table(:stations) do
      add :station_number, :integer
      add :display_order, :integer
      add :is_closed, :boolean
      add :deleted_at, :utc_datetime
      timestamps()
    end

  end
end
