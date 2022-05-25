defmodule Lanpartyseating.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :layout_id, :integer
      add :name, :string

      timestamps()
    end
  end
end
