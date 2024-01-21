defmodule Lanpartyseating.TournamentsLogic do
  import Ecto.Query
  alias Lanpartyseating.SettingsLogic
  alias Lanpartyseating.PubSub
  alias Lanpartyseating.StationLogic
  alias Lanpartyseating.Tournament
  alias Lanpartyseating.TournamentReservation
  alias Lanpartyseating.Repo

  @spec get_all_tournaments :: any
  def get_all_tournaments do
    from(t in Tournament,
      where: is_nil(t.deleted_at),
      order_by: [asc: t.end_date]
    ) |> Repo.all()
  end

  @spec get_all_daily_tournaments :: any
  def get_all_daily_tournaments do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    date = elem(Date.new(now.year, now.month, now.day + 1), 1)
    time = elem(Time.new(4, 0, 0, 0), 1)
    tomorrow = elem(DateTime.new(date, time, "Etc/UTC"), 1)

    from(t in Tournament,
      where: t.end_date > from_now(0, "second"),
      where: t.end_date < ^tomorrow,
      where: is_nil(t.deleted_at)
    ) |> Repo.all()
  end

  def get_upcoming_tournaments do
    tournaments =
      from(t in Tournament,
        where: t.end_date > from_now(0, "second"),
        where: is_nil(t.deleted_at)
      ) |> Repo.all()

    {:ok, tournaments}
  end

  def create_tournament(name, start_time, duration) do
    end_time = DateTime.add(start_time, duration, :hour, Tzdata.TimeZoneDatabase)

    with {:ok, tournament} <- Repo.insert(%Tournament{start_date: start_time, end_date: end_time, name: name}) do
      DynamicSupervisor.start_child(
        Lanpartyseating.ExpirationTaskSupervisor,
        {Lanpartyseating.Tasks.StartTournament, {tournament.start_date, tournament.id}}
      )

      DynamicSupervisor.start_child(
        Lanpartyseating.ExpirationTaskSupervisor,
        {Lanpartyseating.Tasks.ExpireTournament, {tournament.end_date, tournament.id}}
      )

      {:ok, tournaments} = get_upcoming_tournaments()
      Phoenix.PubSub.broadcast(
        PubSub,
        "tournament_update",
        {:tournaments, tournaments}
      )
      {:ok, tournament}
    else
      {:error, err} ->
        {:error, {:create_tournament_failed, err}}
    end
  end

  def delete_tournament(id) do
    from(t in Tournament,
      where: t.id == ^id,
      where: is_nil(t.deleted_at)
    )
    |> Repo.all()
    |> Enum.map(fn res ->
      tournament =
        Ecto.Changeset.change(res,
          deleted_at: DateTime.truncate(DateTime.utc_now(), :second)
        )

      with {:ok, _updated} <- Repo.update(tournament),
           {:ok, stations} <- StationLogic.get_all_stations(),
           {:ok, tournaments} <- get_upcoming_tournaments()
      do
        GenServer.cast(:"expire_tournament_#{id}", :terminate)
        GenServer.cast(:"start_tournament_#{id}", :terminate)
        Phoenix.PubSub.broadcast(
          PubSub,
          "station_update",
          {:stations, stations}
        )
        Phoenix.PubSub.broadcast(
          PubSub,
          "tournament_update",
          {:tournaments, tournaments}
        )
        :ok
      else
        {:error, err} ->
          {:error, {:delete_failed, err}}
      end
    end)
  end

  def create_tournament_reservations_by_range(start_station, end_station, tournament_id) do
    # Input validation
    {:ok, settings} = SettingsLogic.get_settings()

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

        Repo.insert_all(TournamentReservation, reservations)

        Phoenix.PubSub.broadcast(
          PubSub,
          "station_update",
          {:stations, StationLogic.get_all_stations()}
        )

        {:ok, reservations}
    end
  end
end
