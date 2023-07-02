defmodule Lanpartyseating.SeatingLogic do
  import Ecto.Query
  alias Lanpartyseating.Station, as: Station
  alias Lanpartyseating.Seating, as: Seating
  alias Lanpartyseating.Repo, as: Repo
  alias Lanpartyseating.StationLogic, as: StationLogic

  def register_seat(badge_number) do

    if badge_number == "" do
      %{type: "error", message: "Please fill all the fields" }
    else

      # Get last assigned seat
      las = Last_assigned_seat
      |> Repo.one()

      #my_value = last_assigned_seat.last_assigned_seat


      # Get the next available seat
      next_seat = las.last_assigned_seat + 1

      # TODO: update next availabe seat in DB
      las = Ecto.Changeset.change las, last_assigned_seat: next_seat
      case Repo.update las do
        {:ok, result} -> result
        {:error, _} -> nil
      end


      #station = Station
      #|> where(station_number: ^seat_number)
      #|> where([v], is_nil(v.deleted_at))
      #|> Repo.one()

      #isCreatable = case StationLogic.get_station_status(station.id).status do
      #  "occupied"       -> false
      #  "closed"         -> false
      #  "available"      -> true
      #end


      # TODO: Reserve seat
      # Participant gets his seat reserved
      # Also log participant in badge_scans_logs table


      # --> badge number = his bage number
      # --> date scanned = time at which the request was created
      # --> session expiry = date scanned + 45 minutes
      # --> assigned station number = ID of the sation where the participant will be playing
      # --> was removed from AD: false until expiration
      # --> was cancelled: false unless sucessfully cancelled by a lan admin
      # --> date cancelled: logs the date when the cancel request was completed



      # TODO: return seat ID, to be displayed on screen for the participant


      #if isCreatable == true do
      #  {:ok, updated} = Repo.insert(%Reservation{duration: duration, badge: badge_number, station_id: station.id})
      #  %{type: "success", message: "Please fill all the fields", response: Repo.get(Reservation, updated.id)}
      #else
      #  %{type: "error", message: "Unavailable"}
      #end
    end

    to_string(:rand.uniform(70))
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
