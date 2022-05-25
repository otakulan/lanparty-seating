defmodule Lanpartyseating.Repo.Migrations.CreateLayouts do
  use Ecto.Migration

  def change do
    create table(:layouts) do
      add :rows, :integer
      add :cols, :integer

      timestamps()
    end
  end
end
