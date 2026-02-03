defmodule Lanpartyseating.Repo.Migrations.MergeAdminBadgesIntoBadges do
  use Ecto.Migration

  def up do
    # Add new columns to badges
    alter table(:badges) do
      add :is_admin, :boolean, default: false, null: false
      add :label, :string
    end

    # Add unique index on uid for efficient lookups and upserts
    create unique_index(:badges, [:uid])

    # Migrate admin_badges data into badges table
    # admin_badges.badge_number maps to uid (what gets typed/scanned)
    # If uid already exists in badges, update it to be admin
    # Otherwise insert new badge
    execute """
    INSERT INTO badges (uid, serial_key, is_admin, label, is_banned, inserted_at, updated_at)
    SELECT
      UPPER(badge_number),
      badge_number,
      enabled,
      label,
      false,
      inserted_at,
      updated_at
    FROM admin_badges
    ON CONFLICT (uid) DO UPDATE SET
      is_admin = EXCLUDED.is_admin,
      label = EXCLUDED.label
    """

    # Drop old table
    drop table(:admin_badges)

    # Enable pg_trgm extension for trigram-based similarity search
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    # GIN trigram indexes for efficient ILIKE '%search%' queries
    # Without these, ILIKE with leading wildcard causes full table scans
    execute "CREATE INDEX badges_uid_trgm_idx ON badges USING gin (uid gin_trgm_ops)"
    execute "CREATE INDEX badges_serial_key_trgm_idx ON badges USING gin (serial_key gin_trgm_ops)"
  end

  def down do
    # Drop search indexes
    execute "DROP INDEX IF EXISTS badges_serial_key_trgm_idx"
    execute "DROP INDEX IF EXISTS badges_uid_trgm_idx"
    # Not dropping pg_trgm extension as other things may depend on it

    # Recreate admin_badges table
    create table(:admin_badges) do
      add :badge_number, :string, null: false
      add :label, :string, null: false
      add :enabled, :boolean, default: true, null: false
      timestamps()
    end

    create unique_index(:admin_badges, [:badge_number])

    # Migrate admin badges back
    execute """
    INSERT INTO admin_badges (badge_number, label, enabled, inserted_at, updated_at)
    SELECT uid, COALESCE(label, serial_key), is_admin, inserted_at, updated_at
    FROM badges
    WHERE is_admin = true
    """

    # Remove new columns and index
    drop index(:badges, [:uid])

    alter table(:badges) do
      remove :is_admin
      remove :label
    end
  end
end
