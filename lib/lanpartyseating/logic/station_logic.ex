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
    now = NaiveDateTime.utc_now()

    station = Station
    |> where(id: ^stationId)
    |> where([v], is_nil(v.deleted_at))
    |> Repo.one()


    latestReservation = Reservation
    |> where(station_id: ^stationId)
    |> last(:inserted_at)
    |> Repo.one()

    IO.inspect(latestReservation)

    if latestReservation == nil do
      IO.inspect("NNNNIIIIILLLLL")
      "available"

    else

      end_time = NaiveDateTime.add(latestReservation.inserted_at, (latestReservation.duration * 60), :second)

      cond do
        NaiveDateTime.compare(latestReservation.inserted_at, now) == :lt && NaiveDateTime.compare(now, end_time) == :lt -> "occupied"
        station.is_closed -> "closed"
        true -> "available"
      end
    end
  end
end
