defmodule Lanpartyseating.StationLogic do
  import Ecto.Query
  use Timex
  alias Lanpartyseating.Station, as: Station
  alias Lanpartyseating.Repo, as: Repo

  def number_stations do
    Repo.aggregate(Station, :count)
  end

  def get_all_stations do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    stations =
      from(s in Station,
        order_by: [asc: s.id],
        left_join: r in assoc(s, :reservations),
        left_join: tr in assoc(s, :tournament_reservations),
        left_join: t in assoc(tr, :tournament),
        where: is_nil(s.deleted_at),
        preload: [reservations: r, tournament_reservations: {tr, tournament: t}]
      ) |> Repo.all()
    Enum.map(stations, fn station -> Map.merge(%{station: station}, get_station_status(station)) end)
  end

  def get_all_stations_sorted_by_number do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    stations =
      from(s in Station,
        order_by: [asc: s.station_number],
        left_join: r in assoc(s, :reservations),
        left_join: tr in assoc(s, :tournament_reservations),
        left_join: t in assoc(tr, :tournament),
        where: is_nil(s.deleted_at),
        preload: [reservations: r, tournament_reservations: {tr, tournament: t}]
      ) |> Repo.all()
    Enum.map(stations, fn station -> Map.merge(%{station: station}, get_station_status(station)) end)
  end

  def get_station(station_number) do
    from(s in Station,
      order_by: [asc: s.id],
      left_join: r in assoc(s, :reservations),
      left_join: tr in assoc(s, :tournament_reservations),
      left_join: t in assoc(tr, :tournament),
      where: is_nil(s.deleted_at),
      where: s.station_number == ^station_number,
      preload: [reservations: r, tournament_reservations: {tr, tournament: t}]
    ) |> Repo.one()
  end

  def save_station_positions(table) do
    Repo.delete_all(Station)
    table
    |> Enum.each(fn row ->
      row
      |> Enum.each(fn station_number ->
        Repo.insert(%Station{station_number: station_number, display_order: station_number})
      end)
    end)
  end

  def get_station_status(station) do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    case station do
      %Station{tournament_reservations: [res | _]} when
        is_nil(res.tournament.deleted_at) and (res.tournament.end_date > now and res.tournament.start_date < now) ->
          %{status: :reserved, reservation: res}
      %Station{reservations: [res | _]} when
        is_nil(res.deleted_at) and (res.end_date > now and res.start_date < now) ->
          %{status: :occupied, reservation: res}
      %Station{is_closed: true} -> %{status: :broken, reservation: nil}
      %Station{} -> %{status: :available, reservation: nil}
    end
  end
end
