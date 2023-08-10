defmodule Lanpartyseating.Repo.Migrations.AddBadgeTable do
  use Ecto.Migration

  def change do
    create table(:badges) do
      add(:serial_key, :string)
      add(:uid, :string)
      add(:is_banned, :boolean, default: false)
      timestamps()
    end
  end
end
