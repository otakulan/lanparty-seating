defmodule Lanpartyseating.TournamentsLogic do
  import Ecto.Query
  alias Lanpartyseating.Tournament, as: Tournament
  alias Lanpartyseating.Repo, as: Repo

  def get_all_tournaments do
    Repo.all(Tournament)
  end

  def get_all_daily_tournaments do
    Tournament
    |> where([v], v.end_date > from_now(0, "second") )
    |> where([v], is_nil(v.deleted_at))
    |> Repo.all()
  end

end
