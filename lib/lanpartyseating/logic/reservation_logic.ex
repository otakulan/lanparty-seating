defmodule Lanpartyseating.ReservationLogic do
  import Ecto.Query
  require Logger
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Repo, as: Repo
  alias Lanpartyseating.StationLogic, as: StationLogic
  alias Lanpartyseating.BadgesLogic, as: BadgesLogic
  alias Lanpartyseating.PubSub, as: PubSub
  alias LanpartyseatingWeb.Endpoint, as: Endpoint

  def create_reservation(_station_number, _duration, "") do
    {:error, "Please fill all the fields"}
  end

  def create_reservation(station_number, duration, uid) do
    with {:ok, badge} <- BadgesLogic.get_badge(uid) do
      {:ok, station} = StationLogic.get_station(station_number)

      case StationLogic.is_station_available(station) do
        true ->
          Logger.debug("Station is available")
          now = DateTime.truncate(DateTime.utc_now(), :second)
          end_time = DateTime.add(now, duration, :minute)

          case Repo.insert(%Reservation{
                 duration: duration,
                 badge: badge.serial_key,
                 station_id: station.station_number,
                 start_date: now,
                 end_date: end_time,
               }) do
            {:ok, updated} ->
              {:ok, stations} = StationLogic.get_all_stations(now)

              Phoenix.PubSub.broadcast(
                PubSub,
                "station_update",
                {:stations, stations}
              )

              Endpoint.broadcast!(
                "desktop:all",
                "new_reservation",
                %{
                  station_number: station_number,
                  start_date: updated.start_date |> DateTime.to_iso8601(),
                  end_date: updated.end_date |> DateTime.to_iso8601(),
                }
              )

              Logger.debug("Broadcasted station status change to occupied")

              DynamicSupervisor.start_child(
                Lanpartyseating.ExpirationTaskSupervisor,
                {Lanpartyseating.Tasks.ExpireReservation, {end_time, updated.id}}
              )

              Logger.debug("Created expiration task for reservation #{updated.id}")
              {:ok, updated}

            {:error, err} ->
              {:error, {:reservation_failed, err}}
          end

        false ->
          Logger.debug("Station is not available")
          {:error, :station_unavailable}
      end
    end
  end

  def extend_reservation(_id, minutes) when minutes <= 0 do
    {:error, "Reservations can only be extended by a positive non-zero amount of minutes"}
  end

  def extend_reservation(id, minutes) do
    existing_reservation =
      from(r in Reservation,
        where: r.station_id == ^id,
        where: is_nil(r.deleted_at),
        join: s in assoc(r, :station),
        preload: [station: s]
      )
      |> Repo.one()

    new_end_date = DateTime.add(existing_reservation.end_date, minutes, :minute)

    updated_reservation =
      Ecto.Changeset.change(existing_reservation,
        end_date: new_end_date
      )

    reservation =
      with {:ok, reservation} <- Repo.update(updated_reservation) do
        # Terminate the reservation expiration task with the old end date
        GenServer.cast(:"expire_reservation_#{reservation.id}", :terminate)

        # Start a new reservation expiration task with the new end date
        DynamicSupervisor.start_child(
          Lanpartyseating.ExpirationTaskSupervisor,
          {Lanpartyseating.Tasks.ExpireReservation, {new_end_date, reservation.id}}
        )

        Endpoint.broadcast!(
          "desktop:all",
          "extend_reservation",
          %{
            station_number: reservation.station.station_number,
            start_date: reservation.start_date |> DateTime.to_iso8601(),
            end_date: reservation.end_date |> DateTime.to_iso8601(),
          }
        )

        {:ok, stations} = StationLogic.get_all_stations()

        Phoenix.PubSub.broadcast(
          PubSub,
          "station_update",
          {:stations, stations}
        )

        reservation
      else
        {:error, err} ->
          {:error, {:reservation_failed, err}}
      end

    {:ok, reservation}
  end

  def cancel_reservation(id, reason) do
    cancelled =
      from(r in Reservation,
        where: r.station_id == ^id,
        where: is_nil(r.deleted_at),
        join: s in assoc(r, :station),
        preload: [station: s]
      )
      # There should, in theory, only be one non-deleted reservation for a station but let's clean up
      # if that turns out not to be the case.
      |> Repo.all()
      |> Enum.map(fn res ->
        reservation =
          Ecto.Changeset.change(res,
            incident: reason,
            deleted_at: DateTime.truncate(DateTime.utc_now(), :second)
          )

        with {:ok, reservation} <- Repo.update(reservation) do
          GenServer.cast(:"expire_reservation_#{res.id}", :terminate)

          Endpoint.broadcast!(
            "desktop:all",
            "cancel_reservation",
            %{
              station_number: reservation.station.station_number,
              # reservation: updated
            }
          )

          {:ok, stations} = StationLogic.get_all_stations()

          Phoenix.PubSub.broadcast(
            PubSub,
            "station_update",
            {:stations, stations}
          )

          reservation
        else
          {:error, err} ->
            {:error, {:reservation_failed, err}}
        end
      end)

    {:ok, List.last(cancelled)}
  end
end
