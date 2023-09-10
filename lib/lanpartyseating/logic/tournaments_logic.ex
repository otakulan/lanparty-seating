defmodule Lanpartyseating.TournamentsLogic do
  import Ecto.Query
  alias Lanpartyseating.PubSub, as: PubSub
  alias Lanpartyseating.StationLogic, as: StationLogic
  alias Lanpartyseating.Tournament, as: Tournament
  alias Lanpartyseating.Repo, as: Repo

  @spec get_all_tournaments :: any
  def get_all_tournaments do
    Tournament
    |> where([v], is_nil(v.deleted_at))
    |> order_by([v], asc: v.end_date)
    |> Repo.all()
  end

  @spec get_all_daily_tournaments :: any
  def get_all_daily_tournaments do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    date = elem(Date.new(now.year, now.month, now.day + 1), 1)
    time = elem(Time.new(4, 0, 0, 0), 1)
    tomorrow = elem(DateTime.new(date, time, "Etc/UTC"), 1)

    Tournament
    |> where([v], v.end_date > from_now(0, "second") and v.end_date < ^tomorrow)
    |> where([v], is_nil(v.deleted_at))
    |> Repo.all()
  end

  def get_upcoming_tournaments do
    Tournament
    |> where([v], v.end_date > from_now(0, "second"))
    |> where([v], is_nil(v.deleted_at))
    |> Repo.all()
  end

  def create_tournament(name, start_time, duration) do
    end_time = DateTime.add(start_time, duration, :hour, Tzdata.TimeZoneDatabase)

    case Repo.insert(%Tournament{start_date: start_time, end_date: end_time, name: name}) do
      {:ok, tournament} -> {:ok, tournament}
    end
  end

  def delete_tournament(id) do
    Tournament
    |> where(id: ^id)
    |> where([v], is_nil(v.deleted_at))
    |> Repo.all()
    |> Enum.map(fn res ->
      tournament =
        Ecto.Changeset.change(res,
          deleted_at: DateTime.truncate(DateTime.utc_now(), :second)
        )

      case Repo.update(tournament) do
        {:ok, struct} ->
          GenServer.cast(:"expire_tournament_#{id}", :terminate)
          GenServer.cast(:"start_tournament_#{id}", :terminate)
          Phoenix.PubSub.broadcast(
            PubSub,
            "station_update",
            {:stations, StationLogic.get_all_stations()}
          )
          {:ok, struct}
      end
    end)
  end
end
