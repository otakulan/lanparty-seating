defmodule Lanpartyseating.Repo.Migrations.RefactorReservations do
  use Ecto.Migration

  def change do
    alter table(:reservations) do
      add :start_date, :utc_datetime
      add :end_date, :utc_datetime
    end
  end
end
