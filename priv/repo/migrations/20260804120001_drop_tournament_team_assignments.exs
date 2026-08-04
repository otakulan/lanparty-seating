defmodule Lanpartyseating.Repo.Migrations.DropTournamentTeamAssignments do
  use Ecto.Migration

  def up do
    drop_if_exists index(:tournament_team_assignments, [:tournament_id])
    drop_if_exists index(:tournament_team_assignments, [:seat_map_version_id])
    drop_if_exists index(:tournament_team_assignments, [:tournament_id, :group_id], name: :tournament_team_assignments_unique_active_idx)
    drop table(:tournament_team_assignments)
  end

  def down do
    create table(:tournament_team_assignments) do
      add :tournament_id, references(:tournaments, on_delete: :delete_all), null: false
      add :seat_map_version_id, references(:seat_map_versions, on_delete: :delete_all), null: false
      add :group_id, :string, null: false
      add :team_name, :string, null: false
      add :color, :string
      add :label_x, :integer
      add :label_y, :integer
      add :deleted_at, :utc_datetime
      timestamps()
    end

    create index(:tournament_team_assignments, [:tournament_id])
    create index(:tournament_team_assignments, [:seat_map_version_id])

    execute(
      "CREATE UNIQUE INDEX tournament_team_assignments_unique_active_idx ON tournament_team_assignments (tournament_id, group_id) WHERE deleted_at IS NULL",
      "DROP INDEX tournament_team_assignments_unique_active_idx"
    )
  end
end
