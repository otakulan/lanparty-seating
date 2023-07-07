defmodule Lanpartyseating.Repo.Migrations.AddRelationships do
  use Ecto.Migration

  def change do
    alter table(:tournament_reservations) do
      modify :station_id, references(:stations, on_delete: :delete_all)
      modify :tournament_id, references(:tournaments, on_delete: :delete_all)
    end
  end
end
