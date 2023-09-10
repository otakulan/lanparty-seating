defmodule Lanpartyseating.Tasks.StartTournament do
  use GenServer, restart: :transient
  require Logger
  alias Lanpartyseating.StationLogic
  alias Lanpartyseating.PubSub, as: PubSub

  def start_link(arg) do
    {_, tournament_id} = arg
    GenServer.start_link(__MODULE__, arg, name: :"start_tournament_#{tournament_id}")
  end

  @impl true
  def init({start_date, tournament_id}) do
    delay = DateTime.diff(start_date, DateTime.truncate(DateTime.utc_now(), :second), :millisecond) |> max(0)
    Logger.debug("Starting tournament #{tournament_id} in #{delay} milliseconds")
    Process.send_after(self(), :start_tournament, delay)
    {:ok, tournament_id}
  end

  @impl true
  def handle_cast(:terminate, state) do
    Logger.debug("Terminating reservation start task for #{state}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:start_tournament, tournament_id) do
    Logger.debug("Starting tournament #{tournament_id}")

    Phoenix.PubSub.broadcast(
      PubSub,
      "station_update",
      {:stations, StationLogic.get_all_stations()}
    )

    {:stop, :normal, tournament_id}
  end
end
