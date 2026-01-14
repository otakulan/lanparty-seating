defmodule Lanpartyseating.Tasks.ExpireReservation do
  use GenServer, restart: :transient
  import Ecto.Query
  import Ecto.Changeset
  require Logger
  alias Lanpartyseating.StationLogic
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Repo, as: Repo
  alias Lanpartyseating.PubSub, as: PubSub

  def start_link(arg) do
    {_, reservation_id} = arg
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

        {:ok, stations} = StationLogic.get_all_stations()

        Phoenix.PubSub.broadcast(
          PubSub,
          "station_update",
          {:stations, stations}
        )
    end

    {:stop, :normal, reservation_id}
  end
end
