defmodule Lanpartyseating.Repo.Migrations.RemoveUnusedSettingsColumns do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      remove :horizontal_trailing, :integer
      remove :vertical_trailing, :integer
      remove :deleted_at, :utc_datetime
    end
  end
end
