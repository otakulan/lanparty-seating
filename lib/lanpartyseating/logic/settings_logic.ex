defmodule Lanpartyseating.SettingsLogic do
  import Ecto.Query
  require Logger
  alias Lanpartyseating.Setting, as: Setting
  alias Lanpartyseating.LastAssignedSeat, as: LastAssignedSeat
  alias Lanpartyseating.Repo, as: Repo

  def get_settings do
    settings =
      Setting
      |> last(:inserted_at)
      |> Repo.one()

    case settings do
      nil -> {:error, "No settings found"}
      _ -> {:ok, settings}
    end
  end

  @doc """
  Creates an Ecto.Multi that updates the settings table and last_assigned_station table.
  The object returned from this function needs to be written to the database by the caller.
  """
  def settings_db_changes(
        row_padding,
        column_padding,
        horizontal_trailing,
        vertical_trailing
      ) do
    las =
      LastAssignedSeat
      |> Repo.one()

    settings =
      Setting
      |> last(:inserted_at)
      |> Repo.one()

    las =
      Ecto.Changeset.change(las,
        last_assigned_station: 0,
        last_assigned_station_date: DateTime.truncate(DateTime.utc_now(), :second)
      )

    settings =
      Ecto.Changeset.change(settings,
        row_padding: row_padding,
        column_padding: column_padding,
        horizontal_trailing: horizontal_trailing,
        vertical_trailing: vertical_trailing
      )

    Ecto.Multi.new()
    |> Ecto.Multi.insert_or_update(:set_last_assigned_station, las)
    |> Ecto.Multi.insert_or_update(:insert_settings, settings)
  end
end
