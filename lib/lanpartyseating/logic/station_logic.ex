defmodule Lanpartyseating.StationLogic do
  def number_stations do
    Lanpartyseating.Repo.aggregate(Lanpartyseating.Station, :count)
  end

  def get_all_stations do
    Lanpartyseating.Repo.all(Lanpartyseating.Station)
  end
end
