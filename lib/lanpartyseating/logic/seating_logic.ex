defmodule Lanpartyseating.SeatingLogic do
  alias Lanpartyseating.BadgeScanLogs, as: BadgeScanLogs
  alias Lanpartyseating.LastAssignedSeat, as: LastAssignedSeat
  alias Lanpartyseating.SettingsLogic, as: SettingsLogic
  alias Lanpartyseating.Repo, as: Repo

  def register_seat(badge_number) do
    number =
    if badge_number == "" do
      %{type: "error", message: "Please fill all the fields" }
    else
      # Get last assigned seat
      las = LastAssignedSeat
      |> Repo.one()

      settings = SettingsLogic.get_settings()

      # Get the next available seat. Warp around,
      # TODO: Logic should be more complicated, we have to jump above unavailable seats to get to the next available
      # Seats are not reservable only if no available seat is left. Handle this via an error.
      # The user must be informed that no seat is available.
      next_seat = rem(las.last_assigned_seat + 1, settings.columns * settings.rows)

      # Log badge scans, seat ID is set to participant
      expiry_time = DateTime.truncate(DateTime.utc_now() |> DateTime.add(45, :minute), :second)

      # --> badge number = his bage number
      # --> date scanned = time at which the request was created
      # --> session expiry = date scanned + 45 minutes
      # --> assigned station number = ID of the sation where the participant will be playing
      # --> was removed from AD: false until expiration
      # --> was cancelled: false unless sucessfully cancelled by a lan admin
      # --> date cancelled: logs the date when the cancel request was completed
      case Repo.insert(%BadgeScanLogs{badge_number: badge_number,
                                 date_scanned: DateTime.truncate(DateTime.utc_now(), :second),
                                 session_expiry: expiry_time,
                                 assigned_station_number: next_seat,
                                 was_removed_from_ad: false,
                                 was_cancelled: false,
                                 date_cancelled: nil
                                 }) do
                                  {:ok, result} -> result
                                  {:error, error} -> error
                                 end

      # The seat is registered to participant. Update the last reserved seat in DB.
      las = Ecto.Changeset.change las, last_assigned_seat: next_seat, last_assigned_seat_date: DateTime.truncate(DateTime.utc_now(), :second)
      case Repo.update las do
        {:ok, result} -> result
        {:error, error} -> error
      end

      # Return seat ID to be displayed to the participant
      next_seat
    end

    to_string(number)
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
