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

  def save_settings(
        rows,
        columns,
        row_padding,
        column_padding,
        is_diagonally_mirrored,
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

    case Repo.update(las) do
      {:ok, result} -> result
      {:error, error} -> error
    end

    settings =
      Ecto.Changeset.change(settings,
        rows: rows,
        columns: columns,
        row_padding: row_padding,
        column_padding: column_padding,
        is_diagonally_mirrored: is_diagonally_mirrored,
        horizontal_trailing: horizontal_trailing,
        vertical_trailing: vertical_trailing
      )

    Repo.update(settings)
  end
end
