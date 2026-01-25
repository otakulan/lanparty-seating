defmodule Lanpartyseating.Repo.Migrations.CreateAdminBadges do
  use Ecto.Migration

  def change do
    create table(:admin_badges) do
      add :badge_number, :string, null: false
      add :label, :string, null: false
      add :enabled, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:admin_badges, [:badge_number])
  end
end
