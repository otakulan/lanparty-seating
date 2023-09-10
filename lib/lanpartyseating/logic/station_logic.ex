defmodule Lanpartyseating.StationLogic do
  import Ecto.Query
  use Timex
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
    tournament_now = DateTime.add(DateTime.utc_now(), 45, :minute)

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
              where: t.start_date < ^tournament_now,
              where: t.end_date > ^tournament_now,
              where: is_nil(t.deleted_at),
              preload: [tournament: t]
            )
        ]
      )
      |> Repo.all()

    Enum.map(stations, fn station ->
      Map.merge(%{station: station}, get_station_status(station))
    end)
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

    case Repo.update(station) do
      {:ok, result} ->
        Phoenix.PubSub.broadcast(
          PubSub,
          "station_update",
          {:stations, StationLogic.get_all_stations()}
        )
        result
      {:error, _} -> nil
    end
  end

  def get_all_stations_sorted_by_number(now \\ DateTime.utc_now()) do
    tournament_now = DateTime.add(DateTime.utc_now(), 45, :minute)

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
              where: t.start_date < ^tournament_now,
              where: t.end_date > ^tournament_now,
              where: is_nil(t.deleted_at),
              preload: [tournament: t]
            )
        ]
      )
      |> Repo.all()

    Enum.map(stations, fn station ->
      Map.merge(%{station: station}, get_station_status(station))
    end)
  end

  def get_station(station_number, now \\ DateTime.utc_now()) do
    tournament_now = DateTime.add(DateTime.utc_now(), 45, :minute)

    from(s in Station,
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
            where: t.start_date < ^tournament_now,
            where: t.end_date > ^tournament_now,
            where: is_nil(t.deleted_at),
            preload: [tournament: t]
          )
      ]
    )
    |> Repo.one()
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
