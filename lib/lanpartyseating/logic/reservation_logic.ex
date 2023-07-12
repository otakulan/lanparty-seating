defmodule Lanpartyseating.ReservationLogic do
  import Ecto.Query
  require Logger
  alias Lanpartyseating.ExpirationTaskSupervisor, as: ExpirationTaskSupervisor
  alias Lanpartyseating.ExpireReservation, as: ExpireReservation
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Repo, as: Repo
  alias Lanpartyseating.StationLogic, as: StationLogic

  def create_reservation(seat_number, duration, badge_number) do
    IO.inspect(label: "create_reservation called")

    if badge_number == "" do
      {:error, "Please fill all the fields"}
    else
      station = StationLogic.get_station(seat_number)

      if station == nil do
        IO.inspect(
          "In function 'create_reservation', 'get_station' returned nil. This will crash."
        )
      end

      isCreatable =
        case StationLogic.get_station_status(station).status do
          :occupied -> false
          :closed -> false
          :available -> true
        end

      Logger.debug("isCreatable: #{isCreatable}")

      if isCreatable == true do
        now = DateTime.truncate(DateTime.utc_now(), :second)
        end_time = DateTime.add(now, duration, :minute)
        expiry_ms = DateTime.diff(end_time, now, :millisecond)

        IO.inspect("created")

        case Repo.insert(%Reservation{
               duration: duration,
               badge: badge_number,
               station_id: station.id,
               start_date: now,
               end_date: end_time
             }) do
          {:ok, updated} ->
            Task.Supervisor.start_child(ExpirationTaskSupervisor, ExpireReservation, :run, [
              {expiry_ms, updated.id}
            ])

            Logger.debug("Created expiration task for reservation #{updated.id}")
            {:ok, updated}
        end
      else
        IO.inspect(label: "is not creatable")
        {:error, "Station is not available"}
      end
    end
  end

  def cancel_reservation(string_id, reason) do
    {id, _} = Integer.parse(string_id)

    reservation =
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
            struct
            # let it crash
            # {:error, _} -> ...
        end
      end)
  end
end
