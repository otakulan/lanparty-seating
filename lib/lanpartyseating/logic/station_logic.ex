defmodule Lanpartyseating.StationLogic do
  import Ecto.Query
  alias Lanpartyseating.Station, as: Station
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

  def get_station_status(stationId) do
    station = Station
    |> where(id: ^stationId)
    |> where([v], is_nil(v.deleted_at))
    |> Repo.one()

    latestReservation = Reservation
    |> where(station_id: ^stationId)
    |> where([v], v.inserted_at < from_now(0, "second") and from_now(0, "second") < datetime_add(v.inserted_at, v.duration, "minute") )
    |> where([v], is_nil(v.deleted_at))
    |> last(:inserted_at)
    |> Repo.one()

    tournamentReservations = TournamentReservation
    |> join(:inner, [v], p in Tournament, on: v.tournament_id == p.id)
    |> where(station_id: ^stationId)
    |> where([v], is_nil(v.deleted_at))
    |> where([v, p], from_now(0, "second") > datetime_add(p.start_date, -45, "minute") and from_now(0, "second") < p.end_date)
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
