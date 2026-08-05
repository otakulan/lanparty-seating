defmodule Lanpartyseating.Repo.Migrations.DropDefaultMainRoom do
  use Ecto.Migration

  @moduledoc """
             Removes the "Main Room" (and everything under it) that earlier migrations seeded as
             the default catalogue entry.

             A seeded/migrated database previously started with a default Room so the app had
             something to serve before the seat map catalogue existed. Now that the onboarding
             wizard creates the first Room itself, a leftover "Main Room" is just noise, so this
             migration deletes it and its seat maps, versions, and seat slots.

             The `down` re-creates a minimal default Room with a "Main Layout" seat map and one
             published version so rolling back leaves the catalogue usable.
             """

  def up do
    # seat_map_versions first: they reference seat_maps (cascade) and are referenced by
    # rooms.published_version_id (set-null), so delete them while the room still exists.
    execute(
      """
      DELETE FROM #{qualified(:seat_map_versions)}
      WHERE seat_map_id IN (
        SELECT sm.id
        FROM #{qualified(:seat_maps)} sm
        JOIN #{qualified(:rooms)} r ON r.id = sm.room_id
        WHERE r.name = 'Main Room'
      )
      """
    )

    # seat slots and seat maps reference rooms with on_delete: :delete_all; drop the slots
    # before the maps so nothing dangles, then the maps, then the room.
    execute(
      """
      DELETE FROM #{qualified(:seat_slots)}
      WHERE room_id = (SELECT id FROM #{qualified(:rooms)} WHERE name = 'Main Room' LIMIT 1)
      """
    )

    execute(
      """
      DELETE FROM #{qualified(:seat_maps)}
      WHERE room_id = (SELECT id FROM #{qualified(:rooms)} WHERE name = 'Main Room' LIMIT 1)
      """
    )

    # settings.active_room_id references rooms with on_delete: :nilify_all, so clear it
    # explicitly for clarity.
    execute(
      """
      UPDATE #{qualified(:settings)} SET active_room_id = NULL
      WHERE active_room_id = (SELECT id FROM #{qualified(:rooms)} WHERE name = 'Main Room' LIMIT 1)
      """
    )

    execute("DELETE FROM #{qualified(:rooms)} WHERE name = 'Main Room'")
  end

  def down do
    execute(
      """
      INSERT INTO #{qualified(:rooms)} (name, public_id, width, height, inserted_at, updated_at)
      VALUES ('Main Room', 'main-room', 1920, 1080, NOW(), NOW())
      """
    )

    execute(
      """
      INSERT INTO #{qualified(:seat_maps)} (name, room_id, public_id, inserted_at, updated_at)
      SELECT 'Main Layout', r.id, 'main-layout', NOW(), NOW()
      FROM #{qualified(:rooms)} r
      WHERE r.name = 'Main Room'
      LIMIT 1
      """
    )

    execute(
      """
      INSERT INTO #{qualified(:seat_map_versions)} (seat_map_id, revision, width, height, data, inserted_at, updated_at)
      SELECT sm.id, 1, 1920, 1080, '{}', NOW(), NOW()
      FROM #{qualified(:seat_maps)} sm
      WHERE sm.name = 'Main Layout'
      LIMIT 1
      """
    )

    execute(
      """
      UPDATE #{qualified(:rooms)} r
      SET published_version_id = (
        SELECT v.id
        FROM #{qualified(:seat_map_versions)} v
        JOIN #{qualified(:seat_maps)} sm ON sm.id = v.seat_map_id
        WHERE sm.room_id = r.id AND v.revision = 1
        LIMIT 1
      )
      WHERE r.name = 'Main Room'
      """
    )

    execute(
      """
      UPDATE #{qualified(:settings)} SET active_room_id = (
        SELECT id FROM #{qualified(:rooms)} WHERE name = 'Main Room' LIMIT 1
      )
      WHERE id = 1
      """
    )
  end

  # Builds a schema-qualified table reference for raw SQL, honouring the migrator
  # prefix (or the repo's `migration_default_prefix`), mirroring how Ecto's DSL
  # resolves prefixes. Falls back to the bare table name when no prefix is set.
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
