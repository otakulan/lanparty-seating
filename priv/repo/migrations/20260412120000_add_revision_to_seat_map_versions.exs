defmodule Lanpartyseating.Repo.Migrations.AddRevisionToSeatMapVersions do
  use Ecto.Migration

  def up do
    alter table(:seat_map_versions) do
      add :revision, :integer, null: false, default: 1
    end

    # Backfill: within each seat_map, published gets a lower revision than draft
    # so that after publishing the new draft starts at published.revision + 1
    execute(
      """
      WITH ranked AS (
        SELECT id,
          ROW_NUMBER() OVER (
            PARTITION BY seat_map_id
            ORDER BY CASE status WHEN 'published' THEN 0 ELSE 1 END, updated_at
          ) AS rn
        FROM seat_map_versions
        WHERE deleted_at IS NULL
      )
      UPDATE seat_map_versions
      SET revision = ranked.rn
      FROM ranked
      WHERE seat_map_versions.id = ranked.id
      """
    )

    # Drop the old "one published per map" constraint — version_query now uses
    # ORDER BY revision DESC so multiple historical published rows are fine
    execute("DROP INDEX IF EXISTS seat_map_versions_one_published_idx")

    create index(:seat_map_versions, [:seat_map_id, :revision])
  end

  def down do
    drop index(:seat_map_versions, [:seat_map_id, :revision])

    execute(
      """
      CREATE UNIQUE INDEX seat_map_versions_one_published_idx
      ON seat_map_versions (seat_map_id)
      WHERE status = 'published' AND deleted_at IS NULL
      """
    )

    alter table(:seat_map_versions) do
      remove :revision
    end
  end
end
