defmodule Lanpartyseating.ReservationLogic do
  import Ecto.Query
  require Logger
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Repo, as: Repo
  alias Lanpartyseating.StationLogic, as: StationLogic
  alias Lanpartyseating.BadgesLogic, as: BadgesLogic
  alias Lanpartyseating.PubSub, as: PubSub
  alias LanpartyseatingWeb.Endpoint, as: Endpoint

  def create_reservation(station_number, duration, uid) do
    if uid == "" do
      {:error, "Please fill all the fields"}
    else
      # Verifying that badge exists
      badge = BadgesLogic.get_badge(uid)

      if badge == nil do
        {:error, "Unknown badge serial number"}
      else
        station = StationLogic.get_station(station_number)

        if station == nil do
          {:error, "Unknown station number"}
        else
          isAvailable =
            case StationLogic.get_station_status(station).status do
              :reserved -> false
              :occupied -> false
              :broken -> false
              :available -> true
            end

          if isAvailable == true do
            now = DateTime.truncate(DateTime.utc_now(), :second)
            end_time = DateTime.add(now, duration, :minute)

            case Repo.insert(%Reservation{
                   duration: duration,
                   badge: badge.serial_key,
                   station_id: station.id,
                   start_date: now,
                   end_date: end_time
                 }) do
              {:ok, updated} ->
                Phoenix.PubSub.broadcast(
                  PubSub,
                  "station_update",
                  {:stations, StationLogic.get_all_stations(now)}
                )

                Endpoint.broadcast!(
                  "desktop:all",
                  "new_reservation",
                  %{
                    station_number: station_number,
                    # reservation: updated
                  }
                )

                Logger.debug("Broadcasted station status change to occupied")

                DynamicSupervisor.start_child(
                  Lanpartyseating.ExpirationTaskSupervisor,
                  {Lanpartyseating.Tasks.ExpireReservation, {end_time, updated.id}}
                )

                Logger.debug("Created expiration task for reservation #{updated.id}")
                {:ok, updated}
            end
          else
            {:error, "Station is not available"}
          end
        end
      end
    end
  end

  def cancel_reservation(id, reason) do
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

      case Repo.update(reservation) do
        {:ok, reservation} ->
          GenServer.cast(:"expire_reservation_#{res.id}", :terminate)

          Endpoint.broadcast!(
            "desktop:all",
            "cancel_reservation",
            %{
              station_number: reservation.station.station_number,
              # reservation: updated
            }
          )

          Phoenix.PubSub.broadcast(
            PubSub,
            "station_update",
            {:stations, StationLogic.get_all_stations()}
          )

          reservation
          # let it crash
          # {:error, _} -> ...
      end
    end)
  end
end
