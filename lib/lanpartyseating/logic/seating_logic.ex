defmodule Lanpartyseating.SeatingLogic do
  import Ecto.Query
  alias Lanpartyseating.Station, as: Station
  alias Lanpartyseating.Seating, as: Seating
  alias Lanpartyseating.BadgeScanLogs, as: BadgeScanLogs
  alias Lanpartyseating.LastAssignedSeat, as: LastAssignedSeat
  alias Lanpartyseating.Repo, as: Repo
  alias Lanpartyseating.StationLogic, as: StationLogic

  def register_seat(badge_number) do

    next_seat = ""

    if badge_number == "" do
      %{type: "error", message: "Please fill all the fields" }
    else
      # Get last assigned seat
      las = LastAssignedSeat
      |> Repo.one()

      # Get the next available seat
      next_seat = las.last_assigned_seat + 1

      # Log badge scans, seat ID is set to participant
      expiry_time = DateTime.truncate(DateTime.utc_now() |> DateTime.add(45, :minute), :second)

      # --> badge number = his bage number
      # --> date scanned = time at which the request was created
      # --> session expiry = date scanned + 45 minutes
      # --> assigned station number = ID of the sation where the participant will be playing
      # --> was removed from AD: false until expiration
      # --> was cancelled: false unless sucessfully cancelled by a lan admin
      # --> date cancelled: logs the date when the cancel request was completed
      Repo.insert(%BadgeScanLogs{badge_number: badge_number,
                                 date_scanned: DateTime.truncate(DateTime.utc_now(), :second),
                                 session_expiry: expiry_time,
                                 assigned_station_number: next_seat,
                                 was_removed_from_ad: false,
                                 was_cancelled: false,
                                 date_cancelled: nil
                                 })

      # The seat is registered to participant. Update the last reserved seat in DB.
      las = Ecto.Changeset.change las, last_assigned_seat: next_seat, last_assigned_seat_date: DateTime.truncate(DateTime.utc_now(), :second)
      case Repo.update las do
        {:ok, result} -> result
        {:error, _} -> nil
      end

      # TODO: return seat ID, to be displayed on screen for the participant

      #if isCreatable == true do
      #  {:ok, updated} = Repo.insert(%Reservation{duration: duration, badge: badge_number, station_id: station.id})
      #  %{type: "success", message: "Please fill all the fields", response: Repo.get(Reservation, updated.id)}
      #else
      #  %{type: "error", message: "Unavailable"}
      #end
    end

    to_string(next_seat)
  end

  def cancel_seat(seat_id, reason) do

    # TODO: This is for Lan admins. They can cancel a seat (e.g. because is participant gone)

    # Find the current participant assigned to this seat a #cancel him, expire his account

    #id = elem(Integer.parse(string_id),0)
    #reservation = Reservation
    #  |> where(station_id: ^id)
    #  |> where([v], is_nil(v.deleted_at))
    #  |> Repo.one()
    #reservation = Ecto.Changeset.change reservation, incident: reason, deleted_at: DateTime.truncate(DateTime.utc_now(), :second)
    #case Repo.update reservation do
    #  {:ok, struct}       -> struct
    #  {:error, _}         -> "error"
    #end
  end

end
