defmodule Lanpartyseating.Repo.Migrations.AddSetupStateToSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :setup_state, :string, null: false, default: "not_started"
    end
  end
end
