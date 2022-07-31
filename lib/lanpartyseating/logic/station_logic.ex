defmodule Lanpartyseating.StationLogic do
  import Ecto.Query
  alias Lanpartyseating.Station, as: Station
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Repo, as: Repo

  def number_stations do
    Repo.aggregate(Station, :count)
  end

  def get_all_stations do
    Repo.all(Station)
  end

  def get_station_status(stationId) do
    now = DateTime.utc_now()

    station = Station
    |> where(id: ^stationId)
    |> where([v], is_nil(v.deleted_at))
    |> Repo.one()


    latestReservation = Reservation
    |> where(station_id: ^stationId)
    |> Repo.one()

    end_time = NaiveDateTime.add(latestReservation.inserted_at, (latestReservation.duration.minute * 60), :second)

    cond do
      latestReservation.inserted_at <= now && end_time > now -> "occupied"
      station.is_closed -> "closed"
      true -> "unknown"
    end
  end
end
