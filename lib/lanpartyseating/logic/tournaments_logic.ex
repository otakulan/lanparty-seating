defmodule Lanpartyseating.TournamentsLogic do
  import Ecto.Query
  alias Lanpartyseating.PubSub
  alias Lanpartyseating.StationLogic
  alias Lanpartyseating.Tournament
  alias Lanpartyseating.TournamentReservation
  alias Lanpartyseating.Repo

  def get_all_tournaments do
    from(t in Tournament,
      where: is_nil(t.deleted_at),
      order_by: [asc: t.end_date]
    )
    |> Repo.all()
  end

  def get_upcoming_tournaments do
    tournaments =
      from(t in Tournament,
        where: t.end_date > from_now(0, "second"),
        where: is_nil(t.deleted_at)
      )
      |> Repo.all()

    {:ok, tournaments}
  end

  def create_tournament(name, start_time, duration) do
    end_time = DateTime.add(start_time, duration, :hour, Tzdata.TimeZoneDatabase)

    changeset =
      Tournament.changeset(%Tournament{}, %{
        start_date: start_time,
        end_date: end_time,
        name: name,
      })

    with {:ok, tournament} <- Repo.insert(changeset) do
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

  @doc """
  Manually deletes a tournament. Cancels any scheduled start/expire tasks.
  """
  def delete_tournament(id) do
    case do_soft_delete_tournament(id) do
      :ok ->
        GenServer.cast(:"expire_tournament_#{id}", :terminate)
        GenServer.cast(:"start_tournament_#{id}", :terminate)
        :ok

      error ->
        error
    end
  end

  @doc """
  Soft-deletes a tournament that has naturally expired.
  Called by ExpireTournament task. Does NOT cancel scheduled tasks.
  """
  def expire_tournament(id) do
    do_soft_delete_tournament(id)
  end

  defp do_soft_delete_tournament(id) do
    case Repo.get(Tournament, id) do
      nil ->
        {:error, :not_found}

      %Tournament{deleted_at: deleted_at} when not is_nil(deleted_at) ->
        {:error, :already_deleted}

      %Tournament{} = tournament ->
        tournament
        |> Tournament.changeset(%{deleted_at: DateTime.truncate(DateTime.utc_now(), :second)})
        |> Repo.update!()

        {:ok, settings} = Lanpartyseating.SettingsLogic.get_settings()
        {:ok, stations} = StationLogic.get_all_stations(DateTime.utc_now(), settings.tournament_buffer_minutes)
        {:ok, tournaments} = get_upcoming_tournaments()

        Phoenix.PubSub.broadcast(PubSub, "station_update", {:stations, stations})
        Phoenix.PubSub.broadcast(PubSub, "tournament_update", {:tournaments, tournaments})

        :ok
    end
  end

  def create_tournament_reservations_by_range(start_station, end_station, tournament_id) do
    # Input validation
    max_station = StationLogic.number_stations()

    cond do
      start_station < 1 or start_station > max_station ->
        {:error, "Start station is out of bounds"}

      end_station < 1 or end_station > max_station ->
        {:error, "End station is out of bounds"}

      start_station > end_station ->
        {:error, "Start station is after end station"}

      true ->
        now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

        reservations =
          StationLogic.get_stations_by_range(start_station, end_station)
          |> Enum.map(fn station ->
            %{
              tournament_id: tournament_id,
              station_id: station.station_number,
              inserted_at: now,
              updated_at: now,
            }
          end)

        Repo.insert_all(TournamentReservation, reservations)

        {:ok, settings} = Lanpartyseating.SettingsLogic.get_settings()
        {:ok, stations} = StationLogic.get_all_stations(DateTime.utc_now(), settings.tournament_buffer_minutes)
        Phoenix.PubSub.broadcast(PubSub, "station_update", {:stations, stations})

        {:ok, reservations}
    end
  end
end
