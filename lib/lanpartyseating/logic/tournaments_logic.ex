defmodule Lanpartyseating.TournamentsLogic do
  import Ecto.Query
  alias Lanpartyseating.TournamentReservation
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

  def create_tournament(name, start_time, duration, start_station, end_station) do
    end_time = DateTime.add(start_time, duration, :hour, Tzdata.TimeZoneDatabase)

    {:ok, tournament} =
      Repo.insert(%Tournament{start_date: start_time, end_date: end_time, name: name})

    {:ok, stations} = create_reservation_list([], start_station, end_station, tournament.id)

    Repo.insert_all(TournamentReservation, stations)

    {:ok, "Test"}
  end

  def create_reservation_list(stations, current_station, end_station, tournament_id)
      when current_station <= end_station do
    stations = stations ++ [%{station_id: current_station, tournament_id: tournament_id}]

    if current_station < end_station do
      ^stations =
        create_reservation_list(stations, current_station + 1, end_station, tournament_id)
    end

    {:ok, stations}
  end

  def delete_tournament(string_id) do
    {id, _} = Integer.parse(string_id)

    tournament =
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
          {:ok, struct} -> {:ok, struct}
        end
      end)
  end
end
