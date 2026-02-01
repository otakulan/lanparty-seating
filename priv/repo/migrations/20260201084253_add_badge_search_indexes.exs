defmodule Lanpartyseating.Repo.Migrations.AddBadgeSearchIndexes do
  use Ecto.Migration

  def up do
    # Enable pg_trgm extension for trigram-based similarity search
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    # GIN trigram indexes for efficient ILIKE '%search%' queries
    # Without these, ILIKE with leading wildcard causes full table scans
    execute "CREATE INDEX badges_uid_trgm_idx ON badges USING gin (uid gin_trgm_ops)"
    execute "CREATE INDEX badges_serial_key_trgm_idx ON badges USING gin (serial_key gin_trgm_ops)"
  end

  def down do
    execute "DROP INDEX IF EXISTS badges_serial_key_trgm_idx"
    execute "DROP INDEX IF EXISTS badges_uid_trgm_idx"
    # Not dropping pg_trgm extension as other things may depend on it
  end
end
