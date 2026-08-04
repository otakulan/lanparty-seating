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

    # Index names cannot be schema-qualified; the index is created in the
    # parent table's schema, so only the table reference is qualified.
    execute("""
    CREATE UNIQUE INDEX tournament_team_assignments_unique_active_idx
    ON #{qualified(:tournament_team_assignments)} (tournament_id, group_id)
    WHERE deleted_at IS NULL
    """)
  end

  # Builds a schema-qualified table reference for raw SQL, honouring the migrator
  # prefix (or the repo's `migration_default_prefix`), mirroring how Ecto's DSL
  # resolves prefixes. Falls back to the bare name when no prefix is set.
  defp qualified(name) do
    %{name: table_name, prefix: table_prefix} = table(name, prefix: migration_prefix())
    if table_prefix, do: "#{table_prefix}.#{table_name}", else: table_name
  end

  defp migration_prefix do
    prefix() || default_migration_prefix()
  end

  defp default_migration_prefix do
    case repo().config()[:migration_default_prefix] do
      nil -> nil
      value -> to_string(value)
    end
  end
end
