defmodule Lanpartyseating.ReservationLogic do
  import Ecto.Query
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Repo, as: Repo
  alias Lanpartyseating.StationLogic, as: StationLogic

  def create_reservation(seat_number, duration, badge_number) do
    IO.inspect(label: "create_reservation called")

    if badge_number == "" do
      %{type: "error", message: "Please fill all the fields" }
    else

      station = StationLogic.get_station(seat_number)

      isCreatable = case StationLogic.get_station_status(station).status do
        :occupied       -> false
        :closed         -> false
        :available      -> true
      end

      if isCreatable == true do
        now = DateTime.truncate(DateTime.utc_now(), :second)
        end_time = DateTime.add(now, duration, :minute)

        IO.inspect("created")
        case Repo.insert(%Reservation{duration: duration, badge: badge_number, station_id: station.id, start_date: now, end_date: end_time}) do
          {:ok, updated} -> {:ok, updated}
        end
        # %{type: "success", message: "Please fill all the fields", response: Repo.get(Reservation, updated.id)}

      else
        IO.inspect(label: "is not creatable")
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
