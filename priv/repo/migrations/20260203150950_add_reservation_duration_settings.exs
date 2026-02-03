defmodule Lanpartyseating.Repo.Migrations.AddReservationDurationSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :reservation_duration_minutes, :integer, default: 45
      add :tournament_buffer_minutes, :integer, default: 45
    end
  end
end
