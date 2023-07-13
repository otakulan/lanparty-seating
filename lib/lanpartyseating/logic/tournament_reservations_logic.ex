defmodule Lanpartyseating.TournamentReservationLogic do
  alias Lanpartyseating.StationLogic
  alias Lanpartyseating.TournamentReservation
  alias Lanpartyseating.Repo, as: Repo

  def create_tournament_reservations_by_range(start_station, end_station, tournament_id) do
    StationLogic.get_stations_by_range(
      String.to_integer(start_station, 10),
      String.to_integer(end_station, 10)
    )
    |> Enum.map(fn station ->
      %TournamentReservation{
        tournament_id: tournament_id,
        station_id: station.id
      }
    end)
    |> Repo.insert_all()
  end
end
