defmodule Lanpartyseating.ReservationLogic do
  import Ecto.Query
  require Logger
  alias Lanpartyseating.Reservation
  alias Lanpartyseating.Repo
  alias Lanpartyseating.StationLogic
  alias Lanpartyseating.BadgesLogic
  alias Lanpartyseating.PubSub
  alias LanpartyseatingWeb.Endpoint

  def create_reservation(_station_number, _duration, "") do
    {:error, "Please fill all the fields"}
  end

  def create_reservation(station_number, duration, uid) do
    with {:ok, badge} <- BadgesLogic.get_badge(uid),
         {:ok, station} <- StationLogic.get_station(station_number),
         true <- StationLogic.station_available?(station) do
      Logger.debug("Station is available")
      now = DateTime.truncate(DateTime.utc_now(), :second)
      end_time = DateTime.add(now, duration, :minute)

      changeset =
        Reservation.changeset(%Reservation{}, %{
          duration: duration,
          badge: badge.serial_key,
          station_id: station.station_number,
          start_date: now,
          end_date: end_time,
        })

      case Repo.insert(changeset) do
        {:ok, reservation} ->
          {:ok, stations} = StationLogic.get_all_stations(now)

          Phoenix.PubSub.broadcast(PubSub, "station_update", {:stations, stations})

          Endpoint.broadcast!("desktop:all", "new_reservation", %{
            station_number: station_number,
            start_date: reservation.start_date |> DateTime.to_iso8601(),
            end_date: reservation.end_date |> DateTime.to_iso8601(),
          })

          Logger.debug("Broadcasted station status change to occupied")

          DynamicSupervisor.start_child(
            Lanpartyseating.ExpirationTaskSupervisor,
            {Lanpartyseating.Tasks.ExpireReservation, {end_time, reservation.id}}
          )

          Logger.debug("Created expiration task for reservation #{reservation.id}")
          {:ok, reservation}

        {:error, err} ->
          {:error, {:reservation_failed, err}}
      end
    else
      {:error, _} = error -> error
      false -> {:error, :station_unavailable}
    end
  end

  def extend_reservation(_id, minutes) when minutes <= 0 do
    {:error, "Reservations can only be extended by a positive non-zero amount of minutes"}
  end

  def extend_reservation(station_id, minutes) do
    reservation_query =
      from(r in Reservation,
        where: r.station_id == ^station_id,
        where: is_nil(r.deleted_at),
        join: s in assoc(r, :station),
        preload: [station: s]
      )

    case Repo.one(reservation_query) do
      nil ->
        {:error, :not_found}

      %Reservation{} = reservation ->
        new_end_date = DateTime.add(reservation.end_date, minutes, :minute)

        updated =
          reservation
          |> Reservation.changeset(%{end_date: new_end_date})
          |> Repo.update!()

        # Terminate the old expiration task and start a new one with updated end date
        GenServer.cast(:"expire_reservation_#{reservation.id}", :terminate)

        DynamicSupervisor.start_child(
          Lanpartyseating.ExpirationTaskSupervisor,
          {Lanpartyseating.Tasks.ExpireReservation, {new_end_date, reservation.id}}
        )

        Endpoint.broadcast!("desktop:all", "extend_reservation", %{
          station_number: reservation.station.station_number,
          start_date: reservation.start_date |> DateTime.to_iso8601(),
          end_date: new_end_date |> DateTime.to_iso8601(),
        })

        {:ok, stations} = StationLogic.get_all_stations()
        Phoenix.PubSub.broadcast(PubSub, "station_update", {:stations, stations})

        {:ok, updated}
    end
  end

  def cancel_reservation(station_id, reason) do
    # There should, in theory, only be one non-deleted reservation for a station
    # but let's clean up if that turns out not to be the case.
    reservations =
      from(r in Reservation,
        where: r.station_id == ^station_id,
        where: is_nil(r.deleted_at),
        join: s in assoc(r, :station),
        preload: [station: s]
      )
      |> Repo.all()

    case reservations do
      [] ->
        {:error, :not_found}

      reservations ->
        now = DateTime.truncate(DateTime.utc_now(), :second)

        Enum.each(reservations, fn res ->
          res
          |> Reservation.changeset(%{incident: reason, deleted_at: now})
          |> Repo.update!()

          GenServer.cast(:"expire_reservation_#{res.id}", :terminate)

          Endpoint.broadcast!("desktop:all", "cancel_reservation", %{
            station_number: res.station.station_number,
          })
        end)

        # Broadcast station update once after all cancellations
        {:ok, stations} = StationLogic.get_all_stations()
        Phoenix.PubSub.broadcast(PubSub, "station_update", {:stations, stations})

        :ok
    end
  end

  @doc """
  Soft-deletes a reservation that has naturally expired.
  Called by ExpireReservation task. Does not broadcast to desktop clients
  in case the app has been down for some time and new non-tournament reservations have been made since.
  """
  def expire_reservation(reservation_id) do
    case Repo.get(Reservation, reservation_id) do
      nil ->
        {:error, :not_found}

      %Reservation{deleted_at: deleted_at} when not is_nil(deleted_at) ->
        {:error, :already_deleted}

      %Reservation{} = reservation ->
        reservation
        |> Reservation.changeset(%{deleted_at: DateTime.truncate(DateTime.utc_now(), :second)})
        |> Repo.update!()

        {:ok, stations} = StationLogic.get_all_stations()
        Phoenix.PubSub.broadcast(PubSub, "station_update", {:stations, stations})

        :ok
    end
  end
end
