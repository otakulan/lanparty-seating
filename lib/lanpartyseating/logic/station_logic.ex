defmodule Lanpartyseating.StationLogic do
  import Ecto.Query
  use Timex
  import Logger
  alias Lanpartyseating.Station, as: Station
  alias Lanpartyseating.StationPosition, as: StationPosition
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Tournament, as: Tournament
  alias Lanpartyseating.TournamentReservation, as: TournamentReservation
  alias Lanpartyseating.Repo, as: Repo

  def number_stations do
    Repo.aggregate(Station, :count)
  end

  def get_all_stations do
    Enum.map(Repo.all(Station), fn station -> %{station: station, status: get_station_status(station.id)} end)
  end

  def save_station_positions(table) do
    Repo.delete_all(StationPosition)
    Logger.debug("poz")
    table
    |> Enum.with_index()
    |> Enum.each(fn {row, row_index} ->
      row
      |> Enum.with_index()
      |> Enum.each(fn {station_number, col_index} ->
        Logger.debug("poz")
        Repo.insert(%Station{station_number: station_number, display_order: station_number})
        case Repo.insert(%StationPosition{station_number: station_number, row: row_index, column: col_index}) do
          {:error, error} -> Logger.error(error)
        end
      end)
    end)
  end

  def get_station_status(stationId) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    station = Station
    |> where(id: ^stationId)
    |> where([v], is_nil(v.deleted_at))
    |> Repo.one()

    latestReservation = Reservation
    |> where(station_id: ^stationId)
    |> where([v], v.inserted_at < ^now and ^now < datetime_add(v.inserted_at, v.duration, "minute") )
    |> where([v], is_nil(v.deleted_at))
    |> last(:inserted_at)
    |> Repo.one()

    tournamentReservations = TournamentReservation
    |> join(:inner, [v], p in Tournament, on: v.tournament_id == p.id)
    |> where(station_id: ^stationId)
    |> where([v], is_nil(v.deleted_at))
    |> where([v, p], ^now > datetime_add(p.start_date, -45, "minute") and ^now < p.end_date)
    |> Repo.one()

    cond do
      latestReservation == nil && tournamentReservations == nil -> %{status: "available"}
      tournamentReservations != nil && latestReservation == nil -> %{status: "reserved", reservation: tournamentReservations}
      tournamentReservations == nil && latestReservation != nil -> %{status: "occupied", reservation: latestReservation}
      tournamentReservations != nil && latestReservation != nil -> %{status: "occupied", reservation: latestReservation}
      station.is_closed -> %{status: "broken"}
      true -> %{status: "available"}
    end
  end
end
