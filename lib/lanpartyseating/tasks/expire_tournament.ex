defmodule Lanpartyseating.Tasks.ExpireTournament do
  use GenServer, restart: :transient
  require Logger
  alias Lanpartyseating.StationLogic
  alias Lanpartyseating.PubSub, as: PubSub

  def start_link(arg) do
    {_, tournament_id} = arg
    GenServer.start_link(__MODULE__, arg, name: :"expire_tournament_#{tournament_id}")
  end

  @impl true
  def init({end_date, tournament_id}) do
    delay = DateTime.diff(end_date, DateTime.truncate(DateTime.utc_now(), :second), :millisecond) |> max(0)
    Logger.debug("Expiring tournament #{tournament_id} in #{delay} milliseconds")
    Process.send_after(self(), :expire_tournament, delay)
    {:ok, tournament_id}
  end

  @impl true
  def handle_cast(:terminate, state) do
    Logger.debug("Terminating reservation expiration task for #{state}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:expire_tournament, tournament_id) do
    Logger.debug("Expiring tournament #{tournament_id}")

    Phoenix.PubSub.broadcast(
      PubSub,
      "station_update",
      {:stations, StationLogic.get_all_stations()}
    )

    {:stop, :normal, tournament_id}
  end
end
