defmodule Lanpartyseating.Repo.Migrations.CreateReservation do
  use Ecto.Migration

  def change do
    create table(:reservation) do
      add :UID, :string
      add :row, :integer
      add :column, :integer

      timestamps()
    end

  end
end
