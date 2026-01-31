defmodule Lanpartyseating.Repo.Migrations.CreateBadgeScanners do
  use Ecto.Migration

  def change do
    create table(:badge_scanners) do
      add :name, :string, size: 64, null: false
      add :token_hash, :string, null: false
      add :token_prefix, :string, size: 16, null: false
      add :last_seen_at, :utc_datetime
      add :provisioned_at, :utc_datetime
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:badge_scanners, [:token_prefix])
  end
end
