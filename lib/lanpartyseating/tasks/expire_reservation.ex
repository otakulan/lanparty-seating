defmodule Lanpartyseating.ExpireReservation do
  use Task
  import Ecto.Query
  import Ecto.Changeset
  require Logger
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Repo, as: Repo
  alias Lanpartyseating.PubSub, as: PubSub

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run({delay, reservation_id}) do
    Logger.debug("Expiring reservation #{reservation_id} in #{delay} milliseconds")
    Process.sleep(delay)
    Logger.debug("Expiring reservation #{reservation_id}")

    reservation =
      from(r in Reservation,
        where: r.id == ^reservation_id,
        join: s in assoc(r, :station),
        preload: [station: s]
      )
      |> Repo.one()

    now = DateTime.truncate(DateTime.utc_now(), :second)

    deletion =
      change(reservation, deleted_at: now)
      |> Repo.update()

    case deletion do
      {:ok, _} ->
        Logger.debug("Reservation #{reservation_id} expired")

        Phoenix.PubSub.broadcast(
          PubSub,
          "station_status",
          {:available, reservation.station.station_number}
        )
    end
  end
end
