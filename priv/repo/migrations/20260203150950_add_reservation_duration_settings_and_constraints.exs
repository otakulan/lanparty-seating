defmodule Lanpartyseating.Repo.Migrations.AddReservationDurationSettings do
  use Ecto.Migration

  def change do
    execute """
      DELETE FROM settings WHERE id < (SELECT MAX(id) from settings)
    """

    alter table(:settings) do
      add :reservation_duration_minutes, :integer, null: false, default: 45
      add :tournament_buffer_minutes, :integer, null: false, default: 45

      modify :id, :integer, default: 1
      modify :row_padding, :integer, null: false, default: 2
      modify :column_padding, :integer, null: false, default: 1
    end

    create constraint(:settings, :id_must_be_one, check: "id = 1")

    # Ensure the singleton row exists with defaults on fresh databases
    execute """
            INSERT INTO settings (id, row_padding, column_padding, reservation_duration_minutes, tournament_buffer_minutes, inserted_at, updated_at)
            VALUES (1, 2, 1, 45, 45, NOW(), NOW())
            ON CONFLICT DO NOTHING
            """,
            ""
  end
end
