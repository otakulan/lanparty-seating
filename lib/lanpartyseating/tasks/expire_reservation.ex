defmodule Lanpartyseating.Tasks.ExpireReservation do
  use GenServer, restart: :transient
  require Logger
  alias Lanpartyseating.ReservationLogic

  def start_link({_end_date, reservation_id} = arg) do
    GenServer.start_link(__MODULE__, arg, name: :"expire_reservation_#{reservation_id}")
  end

  @impl true
  def init({end_date, reservation_id}) do
    delay =
      DateTime.diff(end_date, DateTime.truncate(DateTime.utc_now(), :second), :millisecond)
      |> max(0)

    Logger.debug("Expiring reservation #{reservation_id} in #{delay} milliseconds")
    Process.send_after(self(), :expire_reservation, delay)
    {:ok, reservation_id}
  end

  @impl true
  def handle_cast(:terminate, state) do
    Logger.debug("Terminating reservation expiration task for #{state}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:expire_reservation, reservation_id) do
    case ReservationLogic.expire_reservation(reservation_id) do
      :ok ->
        Logger.debug("Reservation #{reservation_id} expired")

      {:error, :not_found} ->
        Logger.warning("Reservation #{reservation_id} not found, skipping expiration")

      {:error, :already_deleted} ->
        Logger.debug("Reservation #{reservation_id} already deleted, skipping")
    end

    {:stop, :normal, reservation_id}
  end
end
