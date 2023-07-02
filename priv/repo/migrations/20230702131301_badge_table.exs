defmodule Lanpartyseating.Repo.Migrations.AddBadgeScanLogsTable do
  use Ecto.Migration

  def change do
    create table(:badge_scans_logs) do
      add :badge_number, :string
      add :date_scanned, :utc_datetime
      add :session_expiry, :utc_datetime
      add :assigned_station_number, :integer
      add :was_removed_from_ad, :boolean
      add :was_cancelled, :boolean
      add :date_cancelled, :utc_datetime
      timestamps()
    end
  end
end
