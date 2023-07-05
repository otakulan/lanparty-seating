defmodule Lanpartyseating.ReservationLogic do
  import Ecto.Query
  alias Lanpartyseating.Station, as: Station
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Repo, as: Repo
  alias Lanpartyseating.StationLogic, as: StationLogic

  def create_reservation(seat_number, duration, badge_number) do

    if badge_number == "" do
      %{type: "error", message: "Please fill all the fields" }
    else

      station = Station
      |> where(station_number: ^seat_number)
      |> where([v], is_nil(v.deleted_at))
      |> Repo.one()

      isCreatable = case StationLogic.get_station_status(station.id).status do
        :occupied       -> false
        :closed         -> false
        :available      -> true
      end

      if isCreatable == true do

        IO.inspect("created")
        case Repo.insert(%Reservation{duration: duration, badge: badge_number, station_id: station.id}) do
          {:ok, updated} -> {:ok, updated}
        end
        # %{type: "success", message: "Please fill all the fields", response: Repo.get(Reservation, updated.id)}

      else
        %{type: "error", message: "Unavailable"}
      end
    end
  end

  def cancel_reservation(string_id, reason) do
    id = elem(Integer.parse(string_id),0)
    reservation = Reservation
      |> where(station_id: ^id)
      |> where([v], is_nil(v.deleted_at))
      |> Repo.one()
    reservation = Ecto.Changeset.change reservation, incident: reason, deleted_at: DateTime.truncate(DateTime.utc_now(), :second)
    case Repo.update reservation do
      {:ok, struct}       -> struct
      {:error, _}         -> "error"
    end
  end

end
