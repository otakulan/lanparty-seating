defmodule Lanpartyseating.TournamentsLogic do
  import Ecto.Query
  alias Lanpartyseating.Tournament, as: Tournament
  alias Lanpartyseating.Repo, as: Repo

  def get_all_tournaments do
    Tournament
    |> order_by([v], asc: v.end_date)
    |> Repo.all()
  end

  def get_all_daily_tournaments do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    date = elem(Date.new(now.year, now.month, now.day+1), 1)
    time = elem(Time.new(4, 0, 0, 0), 1)
    tomorrow = elem(DateTime.new(date, time, "Etc/UTC"), 1)

    IO.inspect(tomorrow)

    Tournament
    |> where([v], v.end_date > from_now(0, "second") and v.end_date < ^tomorrow )
    |> where([v], is_nil(v.deleted_at))
    |> Repo.all()
  end

end
