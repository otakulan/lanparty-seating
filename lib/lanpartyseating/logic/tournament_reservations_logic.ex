defmodule Lanpartyseating.TournamentReservationLogic do
  alias Lanpartyseating.PubSub, as: PubSub
  alias Lanpartyseating.SettingsLogic, as: SettingsLogic
  alias Lanpartyseating.StationLogic, as: StationLogic
  alias Lanpartyseating.TournamentReservation, as: TournamentReservation
  alias Lanpartyseating.Repo, as: Repo

  def create_tournament_reservations_by_range(start_station, end_station, tournament_id) do
    # Input validation
    settings = SettingsLogic.get_settings()

    cond do
      start_station < 1 or start_station > settings.columns * settings.rows ->
        {:error, "Start station is out of bounds"}

      end_station < 1 or end_station > settings.columns * settings.rows ->
        {:error, "End station is out of bounds"}

      start_station > end_station ->
        {:error, "Start station is after end station"}

      true ->
        now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        reservations = StationLogic.get_stations_by_range(
          start_station,
          end_station
        )
        |> Enum.map(fn station ->
          %{
            tournament_id: tournament_id,
            station_id: station.id,
            inserted_at: now,
            updated_at: now
          }
        end)

        inserted = Repo.insert_all(TournamentReservation, reservations)

        Phoenix.PubSub.broadcast(
          PubSub,
          "station_update",
          {:stations, StationLogic.get_all_stations()}
        )

        {:ok, inserted}
    end
  end
end
