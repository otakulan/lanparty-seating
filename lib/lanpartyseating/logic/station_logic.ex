defmodule Lanpartyseating.StationLogic do
  import Ecto.Query
  use Timex
  alias Ecto.Changeset
  alias Lanpartyseating.PubSub, as: PubSub
  alias Lanpartyseating.StationLogic, as: StationLogic
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Station, as: Station
  alias Lanpartyseating.TournamentReservation, as: TournamentReservation
  alias Lanpartyseating.Repo, as: Repo

  def number_stations do
    Repo.aggregate(Station, :count)
  end

  def get_all_stations(now \\ DateTime.utc_now()) do
    tournament_buffer = DateTime.add(DateTime.utc_now(), 45, :minute)

    stations =
      from(s in Station,
        order_by: [asc: s.id],
        where: is_nil(s.deleted_at),
        preload: [
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
      |> Repo.all()

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

  def set_station_broken(station_number, is_broken) do
    station =
      from(s in Station,
        where: s.station_number == ^station_number
      ) |> Repo.one()

    station =
      Ecto.Changeset.change(station,
        is_closed: is_broken
      )

    with {:ok, update} <- Repo.update(station),
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

  def get_all_stations_sorted_by_number(now \\ DateTime.utc_now()) do
    tournament_buffer = DateTime.add(DateTime.utc_now(), 45, :minute)

    stations =
      from(s in Station,
        order_by: [asc: s.station_number],
        where: is_nil(s.deleted_at),
        preload: [
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
      |> Repo.all()

    stations_map =
      Enum.map(stations, fn station ->
        Map.merge(%{station: station}, get_station_status(station))
      end)

    {:ok, stations_map}
  end

  def get_station(station_number, now \\ DateTime.utc_now()) do
    tournament_buffer = DateTime.add(DateTime.utc_now(), 45, :minute)

    station = from(s in Station,
      order_by: [asc: s.id],
      where: is_nil(s.deleted_at),
      where: s.station_number == ^station_number,
      preload: [
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
    |> Repo.one()

    case station do
      nil -> {:error, :station_not_found}
      _ -> {:ok, station}
    end
  end

  def save_station_positions(table) do
    Repo.delete_all(Station)

    now_naive =
      NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    positions =
      table
      |> Enum.flat_map(fn row ->
        row
        |> Enum.map(fn station_number ->
          %{station_number: station_number, display_order: station_number, inserted_at: now_naive, updated_at: now_naive}
        end)
      end)

    Repo.insert_all(Station, positions)
    :ok
  end

  def get_station_status(station) do
    case station do
      %Station{is_closed: true} ->
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
