defmodule Lanpartyseating.Tasks.ExpireTournament do
  use GenServer, restart: :transient
  require Logger
  alias Lanpartyseating.TournamentsLogic

  def start_link({_end_date, tournament_id} = arg) do
    GenServer.start_link(__MODULE__, arg, name: :"expire_tournament_#{tournament_id}")
  end

  @impl true
  def init({end_date, tournament_id}) do
    delay =
      DateTime.diff(end_date, DateTime.truncate(DateTime.utc_now(), :second), :millisecond)
      |> max(0)

    Logger.debug("Expiring tournament #{tournament_id} in #{delay} milliseconds")
    Process.send_after(self(), :expire_tournament, delay)
    {:ok, tournament_id}
  end

  @impl true
  def handle_cast(:terminate, state) do
    Logger.debug("Terminating tournament expiration task for #{state}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:expire_tournament, tournament_id) do
    case TournamentsLogic.expire_tournament(tournament_id) do
      :ok ->
        Logger.debug("Tournament #{tournament_id} expired")

      {:error, :not_found} ->
        Logger.warning("Tournament #{tournament_id} not found, skipping expiration")

      {:error, :already_deleted} ->
        Logger.debug("Tournament #{tournament_id} already deleted, skipping")
    end

    {:stop, :normal, tournament_id}
  end
end
