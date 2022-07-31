defmodule Lanpartyseating.Test do
  def number_stations do
    Lanpartyseating.Repo.aggregate(Lanpartyseating.Station, :count)
  end
end
