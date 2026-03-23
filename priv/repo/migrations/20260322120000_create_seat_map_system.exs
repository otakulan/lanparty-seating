defmodule Lanpartyseating.Repo.Migrations.CreateSeatMapSystem do
  use Ecto.Migration

  def up do
    create table(:seat_maps) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :deleted_at, :utc_datetime
      timestamps()
    end

    create unique_index(:seat_maps, [:slug], where: "deleted_at IS NULL")

    create table(:seat_map_versions) do
      add :seat_map_id, references(:seat_maps, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :width, :integer, null: false, default: 1920
      add :height, :integer, null: false, default: 1080
      add :background_kind, :string, null: false, default: "none"
      add :background_value, :text
      add :data, :map, null: false, default: %{}
      add :published_at, :utc_datetime
      add :deleted_at, :utc_datetime
      timestamps()
    end

    create index(:seat_map_versions, [:seat_map_id])

    execute(
      "CREATE UNIQUE INDEX seat_map_versions_one_published_idx ON seat_map_versions (seat_map_id) WHERE status = 'published' AND deleted_at IS NULL",
      "DROP INDEX seat_map_versions_one_published_idx"
    )

    create table(:seat_slots) do
      add :seat_map_id, references(:seat_maps, on_delete: :delete_all), null: false
      add :label, :string, null: false
      add :legacy_station_number, :integer
      add :metadata, :map, null: false, default: %{}
      add :deleted_at, :utc_datetime
      timestamps()
    end

    create index(:seat_slots, [:seat_map_id])
    create unique_index(:seat_slots, [:seat_map_id, :label], where: "deleted_at IS NULL")
    create unique_index(:seat_slots, [:legacy_station_number], where: "legacy_station_number IS NOT NULL")

    create table(:pc_assets) do
      add :code, :string, null: false
      add :hostname, :string
      add :remote_identifier, :string
      add :status, :string, null: false, default: "ready"
      add :metadata, :map, null: false, default: %{}
      add :deleted_at, :utc_datetime
      timestamps()
    end

    create unique_index(:pc_assets, [:code], where: "deleted_at IS NULL")
    create unique_index(:pc_assets, [:hostname], where: "hostname IS NOT NULL AND deleted_at IS NULL")

    create table(:seat_slot_assignments) do
      add :seat_slot_id, references(:seat_slots, on_delete: :delete_all), null: false
      add :pc_asset_id, references(:pc_assets, on_delete: :delete_all), null: false
      add :deleted_at, :utc_datetime
      timestamps()
    end

    create unique_index(:seat_slot_assignments, [:seat_slot_id], where: "deleted_at IS NULL")
    create unique_index(:seat_slot_assignments, [:pc_asset_id], where: "deleted_at IS NULL")

    create table(:seat_slot_statuses) do
      add :seat_slot_id, references(:seat_slots, on_delete: :delete_all), null: false
      add :is_broken, :boolean, null: false, default: false
      add :reason, :string
      timestamps()
    end

    create unique_index(:seat_slot_statuses, [:seat_slot_id])

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

    alter table(:reservations) do
      add :seat_slot_id, references(:seat_slots, on_delete: :nilify_all)
    end

    alter table(:tournament_reservations) do
      add :seat_slot_id, references(:seat_slots, on_delete: :nilify_all)
    end

    create index(:reservations, [:seat_slot_id], where: "deleted_at IS NULL", name: :reservations_seat_slot_id_active_idx)
    create index(:tournament_reservations, [:seat_slot_id], where: "deleted_at IS NULL", name: :tournament_reservations_seat_slot_id_active_idx)

    execute("""
    INSERT INTO seat_maps (name, slug, inserted_at, updated_at)
    VALUES ('Main Room', 'main-room', NOW(), NOW())
    """)

    execute("""
    INSERT INTO seat_slots (seat_map_id, label, legacy_station_number, inserted_at, updated_at)
    SELECT
      (SELECT id FROM seat_maps WHERE slug = 'main-room'),
      chr(65 + sl.y) || lpad((sl.x + 1)::text, 2, '0'),
      s.station_number,
      NOW(),
      NOW()
    FROM stations s
    JOIN station_layout sl ON sl.station_number = s.station_number
    WHERE s.deleted_at IS NULL
    ORDER BY sl.y, sl.x
    """)

    execute("""
    INSERT INTO pc_assets (code, hostname, remote_identifier, status, metadata, inserted_at, updated_at)
    SELECT
      lower(replace(ss.label, ' ', '-')),
      lower(replace(ss.label, ' ', '-')),
      lower(replace(ss.label, ' ', '-')),
      'ready',
      jsonb_build_object('legacy_station_number', ss.legacy_station_number),
      NOW(),
      NOW()
    FROM seat_slots ss
    WHERE ss.deleted_at IS NULL
    ORDER BY ss.label
    """)

    execute("""
    INSERT INTO seat_slot_assignments (seat_slot_id, pc_asset_id, inserted_at, updated_at)
    SELECT
      ss.id,
      pc.id,
      NOW(),
      NOW()
    FROM seat_slots ss
    JOIN pc_assets pc ON pc.code = lower(replace(ss.label, ' ', '-'))
    WHERE ss.deleted_at IS NULL
    """)

    execute("""
    INSERT INTO seat_slot_statuses (seat_slot_id, is_broken, reason, inserted_at, updated_at)
    SELECT
      ss.id,
      COALESCE(st.is_broken, false),
      NULL,
      NOW(),
      NOW()
    FROM seat_slots ss
    LEFT JOIN stations_status st ON st.station_id = ss.legacy_station_number
    WHERE ss.deleted_at IS NULL
    """)

    execute("""
    INSERT INTO seat_map_versions (
      seat_map_id,
      name,
      status,
      width,
      height,
      background_kind,
      background_value,
      data,
      published_at,
      inserted_at,
      updated_at
    )
    SELECT
      sm.id,
      'Initial Published Layout',
      'published',
      GREATEST(COALESCE(MAX(sl.x), 0) + 1, 1) * 120,
      GREATEST(COALESCE(MAX(sl.y), 0) + 1, 1) * 120,
      'none',
      NULL,
      jsonb_build_object(
        'seats',
        COALESCE(
          jsonb_agg(
            jsonb_build_object(
              'seat_slot_id', ss.id,
              'x', sl.x * 120 + 60,
              'y', sl.y * 120 + 60,
              'width', 88,
              'height', 88,
              'rotation', 0,
              'shape', 'rect'
            )
            ORDER BY sl.y, sl.x
          ),
          '[]'::jsonb
        ),
        'objects',
        '[]'::jsonb,
        'groups',
        '[]'::jsonb,
        'meta',
        jsonb_build_object('zoom', 1, 'minScale', 0.4, 'maxScale', 3)
      ),
      NOW(),
      NOW(),
      NOW()
    FROM seat_maps sm
    LEFT JOIN seat_slots ss ON ss.seat_map_id = sm.id AND ss.deleted_at IS NULL
    LEFT JOIN station_layout sl ON sl.station_number = ss.legacy_station_number
    WHERE sm.slug = 'main-room'
    GROUP BY sm.id
    """)

    execute("""
    INSERT INTO seat_map_versions (
      seat_map_id,
      name,
      status,
      width,
      height,
      background_kind,
      background_value,
      data,
      published_at,
      inserted_at,
      updated_at
    )
    SELECT
      seat_map_id,
      'Working Draft',
      'draft',
      width,
      height,
      background_kind,
      background_value,
      data,
      NULL,
      NOW(),
      NOW()
    FROM seat_map_versions
    WHERE status = 'published'
      AND seat_map_id = (SELECT id FROM seat_maps WHERE slug = 'main-room')
    """)

    execute("""
    UPDATE reservations AS r
    SET seat_slot_id = ss.id
    FROM seat_slots ss
    WHERE ss.legacy_station_number = r.station_id
      AND r.seat_slot_id IS NULL
    """)

    execute("""
    UPDATE tournament_reservations AS tr
    SET seat_slot_id = ss.id
    FROM seat_slots ss
    WHERE ss.legacy_station_number = tr.station_id
      AND tr.seat_slot_id IS NULL
    """)
  end

  def down do
    drop index(:tournament_reservations, [:seat_slot_id], name: :tournament_reservations_seat_slot_id_active_idx)
    drop index(:reservations, [:seat_slot_id], name: :reservations_seat_slot_id_active_idx)

    alter table(:tournament_reservations) do
      remove :seat_slot_id
    end

    alter table(:reservations) do
      remove :seat_slot_id
    end

    drop table(:tournament_team_assignments)
    drop table(:seat_slot_statuses)
    drop table(:seat_slot_assignments)
    drop table(:pc_assets)
    drop table(:seat_slots)
    drop table(:seat_map_versions)
    drop table(:seat_maps)
  end
end
