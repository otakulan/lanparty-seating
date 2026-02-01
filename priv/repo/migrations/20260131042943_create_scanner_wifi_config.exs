defmodule Lanpartyseating.Repo.Migrations.CreateScannerWifiConfig do
  use Ecto.Migration

  def change do
    create table(:scanner_wifi_config) do
      add :ssid, :string, size: 32, null: false
      add :password_encrypted, :binary, null: false

      timestamps(type: :utc_datetime)
    end

    # Singleton pattern enforced at application level in ScannerLogic
  end
end
