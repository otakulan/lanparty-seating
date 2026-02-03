defmodule Lanpartyseating.Repo.Migrations.AddAdminCannotBeBannedConstraint do
  use Ecto.Migration

  def up do
    # First, unban any badges that are both admin and banned
    execute "UPDATE badges SET is_banned = false WHERE is_admin = true AND is_banned = true"

    # Then add the constraint to prevent this state in the future
    create constraint(:badges, :admin_cannot_be_banned, check: "NOT (is_admin = true AND is_banned = true)")
  end

  def down do
    drop constraint(:badges, :admin_cannot_be_banned)
  end
end
