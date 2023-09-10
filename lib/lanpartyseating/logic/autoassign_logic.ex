defmodule Lanpartyseating.AutoAssignLogic do
  alias Lanpartyseating.LastAssignedSeat, as: LastAssignedStation
  alias Lanpartyseating.SettingsLogic, as: SettingsLogic
  alias Lanpartyseating.StationLogic, as: StationLogic
  alias Lanpartyseating.Repo, as: Repo

  def register_station(uid) do
    if uid == "" do
      %{type: "error", message: "Please fill all the fields"}
    else
      # TODO: verify that badge uid exists and continue using serial_key. Else error

      # Get last assigned station
      las =
        LastAssignedStation
        |> Repo.one()

      # Warp around the first station we look from when we reach the maximum number of stations
      settings = SettingsLogic.get_settings()
      next_station = rem(las.last_assigned_station, settings.columns * settings.rows) + 1

      stations = StationLogic.get_all_stations_sorted_by_number()

      # Find the first result matching this condition
      # The stations collection is split in half and we swap the end with the start so that
      # we iterate on the last part first. This is so we search from the current index, but we still search all the stations.
      result =
        Enum.find(
          Enum.drop(stations, next_station - 1) ++ Enum.take(stations, next_station - 1),
          fn element ->
            case StationLogic.get_station_status(element.station) do
              %{status: :available, reservation: _} -> true
              _ -> false
            end
          end
        )

      case result do
        nil ->
          nil

        result2 ->
          next_station = result2.station.station_number

          # The station is registered to participant. Update the last reserved station in DB.
          las =
            Ecto.Changeset.change(las,
              last_assigned_station: next_station,
              last_assigned_station_date: DateTime.truncate(DateTime.utc_now(), :second)
            )

          case Repo.update(las) do
            {:ok, _} -> next_station
            {:error, error} -> error
          end
      end
    end
  end
end
