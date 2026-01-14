defmodule Lanpartyseating.Tasks.StartTournament do
  use GenServer, restart: :transient
  import Ecto.Query
  require Logger
  alias Lanpartyseating.Repo
  alias Lanpartyseating.TournamentReservation
  alias LanpartyseatingWeb.Endpoint
  alias Lanpartyseating.StationLogic
  alias Lanpartyseating.PubSub

  def start_link(arg) do
    {_, tournament_id} = arg
    GenServer.start_link(__MODULE__, arg, name: :"start_tournament_#{tournament_id}")
  end

  @impl true
  def init({start_date, tournament_id}) do
    delay =
      DateTime.diff(start_date, DateTime.truncate(DateTime.utc_now(), :second), :millisecond)
      |> max(0)

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
    Logger.info("Starting tournament #{tournament_id}")

    {:ok, stations} = StationLogic.get_all_stations()

    Phoenix.PubSub.broadcast(
      PubSub,
      "station_update",
      {:stations, stations}
    )

    reservations =
      from(r in TournamentReservation,
        where: r.tournament_id == ^tournament_id,
        join: s in assoc(r, :station),
        preload: [station: s]
      )
      |> Repo.all()

    Logger.info("Found #{length(reservations)} tournament reservations for tournament #{tournament_id}")

    Enum.each(reservations, fn res ->
      Logger.info("Broadcasting tournament_start to station #{res.station.station_number}")

      Endpoint.broadcast(
        "desktop:all",
        "tournament_start",
        %{
          station_number: res.station.station_number,
        }
      )
    end)

    {:stop, :normal, tournament_id}
  end
end
