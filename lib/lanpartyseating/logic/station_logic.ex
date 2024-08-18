defmodule Lanpartyseating.StationLogic do
  import Ecto.Query
  alias Lanpartyseating.StationLayout
  use Timex
  alias Ecto.Changeset
  alias Lanpartyseating.PubSub, as: PubSub
  alias Lanpartyseating.StationLogic, as: StationLogic
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Station, as: Station
  alias Lanpartyseating.TournamentReservation, as: TournamentReservation
  alias Lanpartyseating.Repo, as: Repo
  alias Lanpartyseating.StationLayout, as: Layout
  alias Lanpartyseating.StationStatus, as: Status

  def number_stations do
    Repo.aggregate(Station, :count)
  end

  def get_station_query(now \\ DateTime.utc_now()) do
    tournament_buffer = DateTime.add(DateTime.utc_now(), 45, :minute)

    from(s in Station,
        order_by: [asc: s.station_number], # only needed by autoassign
        where: is_nil(s.deleted_at),
        preload: [
          stations_status:
            ^from(Status), # may return nil
          station_layout:
            ^from(Layout),
          reservations:
            ^from(
              r in Reservation,
              where: r.start_date <= ^now,
              where: r.end_date > ^now,
              where: is_nil(r.deleted_at),
              order_by: [desc: r.inserted_at]
            ),
          tournament_reservations:
            ^from(tr in TournamentReservation,
              join: t in assoc(tr, :tournament),
              where: t.start_date < ^tournament_buffer,
              where: t.end_date > ^now,
              where: is_nil(t.deleted_at),
              preload: [tournament: t]
            )
        ]
      )
  end

  def get_all_stations(now \\ DateTime.utc_now()) do
    stations = get_station_query(now) |> Repo.all()

    case stations do
      [] ->
        {:error, :no_stations}
      _ ->
        stations_map =
          Enum.map(stations, fn station ->
            Map.merge(%{station: station}, get_station_status(station))
          end)
        {:ok, stations_map}
    end
  end

  def get_station_layout() do
    rows = Repo.all(from(Layout))
    Enum.map(rows, fn r -> {{r.x, r.y}, r.station_number} end)
      |> Enum.into(%{})
  end

  def stations_by_xy(stations) do
    by_pos = stations
      |> Enum.map(fn s -> {{s.station.station_layout.x, s.station.station_layout.y}, s} end)
      |> Enum.into(%{})

    {max_x, max_y} = Map.keys(by_pos)
      |> Enum.reduce({0, 0}, fn {acc_x, acc_y}, {x, y} -> {max(x, acc_x), max(y, acc_y)} end)

    # {columns, rows}
    {by_pos, {max_x + 1, max_y + 1}}
  end

  def set_station_broken(station_number, is_broken) do
    result = Repo.insert(
      %Lanpartyseating.StationStatus{station_id: station_number, is_broken: is_broken},
      on_conflict: [set: [is_broken: is_broken]],
      conflict_target: :station_id
    )

    with {:ok, update} <- result,
         {:ok, stations} <- StationLogic.get_all_stations()
    do
      Phoenix.PubSub.broadcast(
        PubSub,
        "station_update",
        {:stations, stations}
      )
      {:ok, update}
    else
      {:error, _} ->
        {:error, :station_not_found}
    end
  end

  def get_station(station_number, now \\ DateTime.utc_now()) do
    station = get_station_query(now) |> Repo.one()

    case station do
      nil -> {:error, :station_not_found}
      _ -> {:ok, station}
    end
  end

  def save_stations(grid) do
    now_naive =
      NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    stations = grid
      |> Enum.map(fn {_xy, station_number} ->
        %{station_number: station_number, inserted_at: now_naive, updated_at: now_naive}
      end)
    layout = grid
      |> Enum.map(fn {{x, y}, num} -> %{station_number: num, x: x, y: y} end)
      #|> Enum.reduce(Ecto.Multi.new(), fn row, multi -> Ecto.Multi.insert(multi, {:insert_position, row.station_number}, row) end)

      Ecto.Multi.new()
      # because of the foreign key these need to be deleted and inserted specifically in this order
      |> Ecto.Multi.delete_all(:delete_stations, from(Lanpartyseating.Station))
      |> Ecto.Multi.delete_all(:delete_layout, from(Lanpartyseating.StationLayout))
      |> Ecto.Multi.insert_all(:insert_layout, Lanpartyseating.StationLayout, layout)
      |> Ecto.Multi.insert_all(:insert_stations, Station, stations)
  end

  def get_station_status(station) do
    case station do
      %Station{stations_status: %{is_broken: true}} ->
        %{status: :broken, reservation: nil}

      %Station{tournament_reservations: [res | _]}
      when is_nil(res.tournament.deleted_at) ->
        %{status: :reserved, reservation: res}

      %Station{reservations: [res | _]}
      when is_nil(res.deleted_at) ->
        %{status: :occupied, reservation: res}

      %Station{} ->
        %{status: :available, reservation: nil}
    end
  end

  def is_station_available(station) do
    %{status: status} = StationLogic.get_station_status(station)

    case status do
      :reserved -> false
      :occupied -> false
      :broken -> false
      :available -> true
    end
  end

  def get_stations_by_range(start_number, end_number) do
    from(s in Station,
      order_by: [asc: s.station_number],
      where: is_nil(s.deleted_at),
      where: s.station_number >= ^start_number,
      where: s.station_number <= ^end_number
    )
    |> Repo.all()
  end
end
