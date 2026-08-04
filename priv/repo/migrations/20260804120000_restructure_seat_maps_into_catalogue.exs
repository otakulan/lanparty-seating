defmodule Lanpartyseating.Repo.Migrations.RestructureSeatMapsIntoCatalogue do
  use Ecto.Migration

  def up do
    # Crockford base32 helper for generating public_ids in SQL.
    execute("""
    CREATE OR REPLACE FUNCTION crockford32(n bigint) RETURNS text AS $$
    DECLARE
      alphabet text := '0123456789abcdefghjkmnpqrstvwxyz';
      result text := '';
      v bigint := n;
    BEGIN
      IF v = 0 THEN
        RETURN '0';
      END IF;
      WHILE v > 0 LOOP
        result := substr(alphabet, ((v % 32) + 1)::int, 1) || result;
        v := v / 32;
      END LOOP;
      RETURN result;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """)

    # 1. rooms table -----------------------------------------------------------
    create table(:rooms) do
      add :name, :string, null: false
      add :public_id, :string
      add :width, :integer, null: false, default: 1920
      add :height, :integer, null: false, default: 1080
      add :published_version_id, references(:seat_map_versions, on_delete: :nilify_all), null: true
      add :deleted_at, :utc_datetime
      timestamps()
    end

    create unique_index(:rooms, [:public_id], where: "deleted_at IS NULL")

    # Seed one Room from the existing main seat map, sizing the canvas from its
    # published version's dimensions.
    execute("""
    INSERT INTO #{qualified(:rooms)} (name, width, height, inserted_at, updated_at)
    SELECT 'Main Room',
           COALESCE((SELECT width FROM #{qualified(:seat_map_versions)}
                     WHERE seat_map_id = sm.id AND status = 'published'
                     ORDER BY revision DESC LIMIT 1), 1920),
           COALESCE((SELECT height FROM #{qualified(:seat_map_versions)}
                     WHERE seat_map_id = sm.id AND status = 'published'
                     ORDER BY revision DESC LIMIT 1), 1080),
           NOW(), NOW()
    FROM #{qualified(:seat_maps)} sm
    WHERE sm.slug = 'main-room' AND sm.deleted_at IS NULL
    LIMIT 1
    """)

    execute("UPDATE #{qualified(:rooms)} SET public_id = lpad(crockford32(id), 8, '0')")

    # Point the Room at the published version (highest published revision).
    execute("""
    UPDATE #{qualified(:rooms)}
    SET published_version_id = (
      SELECT v.id FROM #{qualified(:seat_map_versions)} v
      JOIN #{qualified(:seat_maps)} sm ON sm.id = v.seat_map_id
      WHERE sm.slug = 'main-room' AND sm.deleted_at IS NULL
        AND v.status = 'published' AND v.deleted_at IS NULL
      ORDER BY v.revision DESC
      LIMIT 1
    )
    WHERE name = 'Main Room'
    """)

    # 2. seat_maps: reparent to Room, add public_id, rename ---------------------
    drop_if_exists index(:seat_maps, [:slug], name: :seat_maps_deleted_at_slug_index)
    drop_if_exists index(:seat_maps, [:slug], name: :seat_maps_slug_index)

    alter table(:seat_maps) do
      add :room_id, references(:rooms, on_delete: :delete_all), null: true
      add :public_id, :string
    end

    execute("""
    UPDATE #{qualified(:seat_maps)} SET room_id = (SELECT id FROM #{qualified(:rooms)} WHERE name = 'Main Room' LIMIT 1)
    WHERE deleted_at IS NULL
    """)

    execute("""
    UPDATE #{qualified(:seat_maps)}
    SET name = 'Main Layout'
    WHERE slug = 'main-room' AND deleted_at IS NULL
    """)

    execute("UPDATE #{qualified(:seat_maps)} SET public_id = lpad(crockford32(id), 8, '0') WHERE public_id IS NULL")

    alter table(:seat_maps) do
      modify :public_id, :string, null: false
    end

    execute("ALTER TABLE #{qualified(:seat_maps)} ALTER COLUMN room_id SET NOT NULL")

    create unique_index(:seat_maps, [:room_id, :name], where: "deleted_at IS NULL")
    create unique_index(:seat_maps, [:public_id], where: "deleted_at IS NULL")

    alter table(:seat_maps) do
      remove :slug
    end

    # 3. seat_slots: reparent Room ---------------------------------------------
    drop_if_exists index(:seat_slots, [:seat_map_id, :label], name: :seat_slots_seat_map_id_label_index)
    drop_if_exists index(:seat_slots, [:seat_map_id], name: :seat_slots_seat_map_id_index)

    alter table(:seat_slots) do
      add :room_id, references(:rooms, on_delete: :delete_all), null: true
    end

    execute("""
    UPDATE #{qualified(:seat_slots)} ss
    SET room_id = sm.room_id
    FROM #{qualified(:seat_maps)} sm
    WHERE ss.seat_map_id = sm.id AND ss.deleted_at IS NULL
    """)

    execute("ALTER TABLE #{qualified(:seat_slots)} ALTER COLUMN room_id SET NOT NULL")

    create unique_index(:seat_slots, [:room_id, :label], where: "deleted_at IS NULL")
    create index(:seat_slots, [:room_id])

    alter table(:seat_slots) do
      remove :seat_map_id
    end

    # 4. seat_map_versions: drop status/name, retire redundant draft ------------
    # Soft-delete the draft when it is an exact duplicate of the published version.
    execute("""
    UPDATE #{qualified(:seat_map_versions)} d
    SET deleted_at = NOW()
    FROM #{qualified(:seat_map_versions)} p
    WHERE d.seat_map_id = p.seat_map_id
      AND d.status = 'draft' AND d.deleted_at IS NULL
      AND p.status = 'published' AND p.deleted_at IS NULL
      AND d.data = p.data
    """)

    alter table(:seat_map_versions) do
      remove :status
      remove :name
    end

    # 5. settings: active_room_id ----------------------------------------------
    alter table(:settings) do
      add :active_room_id, references(:rooms, on_delete: :nilify_all), null: true
    end

    execute("""
    UPDATE #{qualified(:settings)} SET active_room_id = (SELECT id FROM #{qualified(:rooms)} WHERE name = 'Main Room' LIMIT 1)
    WHERE id = 1
    """)

    execute("DROP FUNCTION IF EXISTS crockford32(bigint)")
  end

  def down do
    # 5. settings
    alter table(:settings) do
      remove :active_room_id
    end

    # 4. seat_map_versions: restore status/name
    alter table(:seat_map_versions) do
      add :status, :string, null: false, default: "draft"
      add :name, :string, null: false, default: "Working Draft"
    end

    # 3. seat_slots: restore seat_map_id
    drop index(:seat_slots, [:room_id, :label], where: "deleted_at IS NULL")
    drop index(:seat_slots, [:room_id])

    alter table(:seat_slots) do
      add :seat_map_id, references(:seat_maps, on_delete: :delete_all), null: true
    end

    execute("""
    UPDATE #{qualified(:seat_slots)} ss
    SET seat_map_id = sm.id
    FROM #{qualified(:seat_maps)} sm
    WHERE ss.room_id = sm.room_id AND ss.deleted_at IS NULL
    """)

    execute("ALTER TABLE #{qualified(:seat_slots)} ALTER COLUMN seat_map_id SET NOT NULL")

    alter table(:seat_slots) do
      remove :room_id
    end

    create index(:seat_slots, [:seat_map_id], name: :seat_slots_seat_map_id_index)
    create unique_index(:seat_slots, [:seat_map_id, :label], where: "deleted_at IS NULL", name: :seat_slots_seat_map_id_label_index)

    # 2. seat_maps: restore slug
    drop index(:seat_maps, [:room_id, :name], where: "deleted_at IS NULL")
    drop index(:seat_maps, [:public_id], where: "deleted_at IS NULL")

    alter table(:seat_maps) do
      add :slug, :string
    end

    execute("""
    UPDATE #{qualified(:seat_maps)}
    SET slug = 'main-room', name = 'Main Room'
    WHERE name = 'Main Layout' AND deleted_at IS NULL
    """)

    execute("""
    UPDATE #{qualified(:seat_maps)} SET slug = lower(replace(name, ' ', '-'))
    WHERE slug IS NULL AND deleted_at IS NULL
    """)

    # Restore the per-slug uniqueness constraint exactly as it was.
    create unique_index(:seat_maps, [:deleted_at, :slug], where: "deleted_at IS NULL", name: :seat_maps_deleted_at_slug_index)

    alter table(:seat_maps) do
      modify :slug, :string, null: false
      remove :public_id
      remove :room_id
    end

    # 1. rooms
    drop table(:rooms)
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
