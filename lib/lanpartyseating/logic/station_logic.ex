defmodule Lanpartyseating.StationLogic do
  import Ecto.Query
  import Logger
  use Timex
  alias Lanpartyseating.Station, as: Station
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Tournament, as: Tournament
  alias Lanpartyseating.TournamentReservation, as: TournamentReservation
  alias Lanpartyseating.Repo, as: Repo

  def number_stations do
    Repo.aggregate(Station, :count)
  end

  def get_all_stations do
    Enum.map(from(s in Station, order_by: [asc: s.id]) |> Repo.all(), fn station -> Map.merge(%{station: station}, get_station_status(station.id)) end)
  end

  def save_station_positions(table) do
    Repo.delete_all(Station)
    table
    |> Enum.each(fn row ->
      row
      |> Enum.each(fn station_number ->
        IO.inspect(station_number)
        Repo.insert(%Station{station_number: station_number, display_order: station_number})
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
      latestReservation == nil && tournamentReservations == nil -> %{status: :available, reservation: nil}
      tournamentReservations != nil && latestReservation == nil -> %{status: :reserved, reservation: tournamentReservations}
      tournamentReservations == nil && latestReservation != nil -> %{status: :occupied, reservation: latestReservation}
      tournamentReservations != nil && latestReservation != nil -> %{status: :occupied, reservation: latestReservation}
      station.is_closed -> %{status: :broken, reservation: nil}
      true -> %{status: :available, reservation: nil}
    end
  end
end
