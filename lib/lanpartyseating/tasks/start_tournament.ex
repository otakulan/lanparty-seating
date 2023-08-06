defmodule Lanpartyseating.Tasks.StartTournament do
  use GenServer, restart: :transient
  import Ecto.Query
  require Logger
  alias Lanpartyseating.Tournament, as: Tournament
  alias Lanpartyseating.Repo, as: Repo
  alias Lanpartyseating.PubSub, as: PubSub

  def start_link(arg) do
    {_, tournament_id} = arg
    GenServer.start_link(__MODULE__, arg, name: :"start_tournament_#{tournament_id}")
  end

  @impl true
  def init({start_date, tournament_id}) do
    delay = DateTime.diff(start_date, DateTime.truncate(DateTime.utc_now(), :second), :millisecond) |> max(0)
    Logger.debug("Starting tournament #{tournament_id} in #{delay} milliseconds")
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
    Logger.debug("Starting tournament #{tournament_id}")

    tournament =
      from(t in Tournament,
        where: t.id == ^tournament_id,
        join: tr in assoc(t, :tournament_reservations),
        join: s in assoc(tr, :station),
        preload: [tournament_reservations: {tr, station: s}]
      ) |> Repo.one()

    Enum.map(tournament.tournament_reservations, fn reservation ->
      Phoenix.PubSub.broadcast(
        PubSub,
        "station_status",
        {:reserved, reservation.station.station_number, reservation}
      )
    end)
    {:stop, :normal, tournament_id}
  end
end
