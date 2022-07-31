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
    |> Repo.one()

    latestReservation = Reservation
    |> where(station_id: ^stationId)
    |> Repo.one()

    # case Repo.update settings do
    #   {:ok, struct}       -> settings
    #   {:error, changeset} -> nil
    # end
  end
end
