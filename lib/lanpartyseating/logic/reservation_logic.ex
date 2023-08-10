defmodule Lanpartyseating.ReservationLogic do
  import Ecto.Query
  require Logger
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Repo, as: Repo
  alias Lanpartyseating.StationLogic, as: StationLogic
  alias Lanpartyseating.BadgesLogic, as: BadgesLogic
  alias Lanpartyseating.PubSub, as: PubSub

  def create_reservation(station_number, duration, uid) do
    if uid == "" do
      {:error, "Please fill all the fields"}
    else
      # Verifying that badge exists
      badge = BadgesLogic.get_badge(uid)

      IO.inspect(badge)

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
                  "station_status",
                  {:occupied, station_number, updated}
                )

                DynamicSupervisor.start_child(
                  Lanpartyseating.ExpirationTaskSupervisor,
                  {Lanpartyseating.Tasks.ExpireReservation, {end_time, updated.id}}
                )

                Logger.debug("Created expiration task for reservation #{updated.id}")
                {:ok, updated}
            end
          else
            IO.inspect(label: "is not creatable")
            {:error, "Station is not available"}
          end
        end
      end
    end
  end

  def cancel_reservation(id, station_number, reason) do
    Reservation
    |> where(station_id: ^id)
    |> where([v], is_nil(v.deleted_at))
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
        {:ok, struct} ->
          GenServer.cast(:"expire_reservation_#{res.id}", :terminate)

          Phoenix.PubSub.broadcast(
            PubSub,
            "station_status",
            {:available, station_number}
          )

          struct
          # let it crash
          # {:error, _} -> ...
      end
    end)
  end
end
