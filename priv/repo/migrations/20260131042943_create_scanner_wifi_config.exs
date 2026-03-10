defmodule Lanpartyseating.Repo.Migrations.CreateScannerWifiConfig do
  use Ecto.Migration

  def change do
    create table(:scanner_wifi_config) do
      add :ssid, :string, size: 32, null: false
      add :password_encrypted, :binary, null: false

      timestamps(type: :utc_datetime)
    end

    # Enforce singleton at database level (same pattern as settings table)
    execute "ALTER TABLE scanner_wifi_config ALTER COLUMN id SET DEFAULT 1",
            "ALTER TABLE scanner_wifi_config ALTER COLUMN id DROP DEFAULT"

    create constraint(:scanner_wifi_config, :id_must_be_one, check: "id = 1")
  end
end
