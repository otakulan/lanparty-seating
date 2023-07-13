defmodule LanpartyseatingWeb.TournamentsLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.TournamentsLogic, as: TournamentsLogic
  alias Lanpartyseating.TournamentReservationLogic, as: TournamentReservationLogic

  def mount(_params, _session, socket) do
    tournaments = TournamentsLogic.get_all_tournaments()

    socket =
      socket
      |> assign(:tournaments, tournaments)
      |> assign(:tournamentsCount, length(tournaments))

    {:ok, socket}
  end

  def handle_event(
        "delete_tournament",
        %{"tournament_id" => tournament_id},
        socket
      ) do
    {id, _} = Integer.parse(tournament_id)

    TournamentsLogic.delete_tournament(id)

    tournaments =
      socket.assigns.tournaments
      |> Enum.filter(fn tournament ->
        tournament.id != id
      end)

    socket =
      socket
      |> assign(:tournaments, tournaments)

    {:noreply, socket}
  end

  def handle_event(
        "create_tournament",
        %{
          "name" => name,
          "start_time" => start_time,
          "duration" => duration,
          "start_station" => start_station,
          "end_station" => end_station
        },
        socket
      ) do
    # Convering time string to UTC shifted TimeDate
    {:ok, start_time} = Timex.parse(start_time, "{ISO:Extended:Z}")

    {:ok, start_time} =
      DateTime.from_naive(start_time, "America/Toronto", Tzdata.TimeZoneDatabase)

    {:ok, start_time} = DateTime.shift_zone(start_time, "Etc/UTC", Tzdata.TimeZoneDatabase)

    # Creating tournament
    {:ok, tournament} =
      TournamentsLogic.create_tournament(
        name,
        start_time,
        String.to_integer(duration, 10)
      )

    # Creating station reservations for the tournament
    TournamentReservationLogic.create_tournament_reservations_by_range(
      String.to_integer(start_station, 10),
      String.to_integer(end_station, 10),
      tournament.id
    )

    # TODO:
    # Phoenix.PubSub.broadcast(
    #   PubSub,
    #   "tournament_created",
    #   {:available, String.to_integer(station_number)}
    # )

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="jumbotron">
      <h1 style="font-size:30px">Tournaments</h1>
      <TournamentModalComponent.tournament_modal />

      <div class="flex flex-wrap w-full mt-3">
        <div class="flex flex-row w-full " }>
          <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
            <h2><u>Name</u></h2>
          </div>
          <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
            <h2><u>Start Time</u></h2>
          </div>
          <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
            <h2><u>End Time</u></h2>
          </div>
          <div class="flex flex-col flex-1 mx-1 h-14 grow" }>

          </div>
        </div>
        <%= for tournament <- @tournaments do %>
          <div class="flex flex-row w-full " }>
            <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
              <h3>
                <%= tournament.name %>
              </h3>
            </div>
            <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
              <h3>
                <%= Calendar.strftime(
                  tournament.start_date |> Timex.to_datetime("America/Montreal"),
                  "%y/%m/%d -> %H:%M"
                ) %>
              </h3>
            </div>
            <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
              <h3>
                <%= Calendar.strftime(
                  tournament.end_date |> Timex.to_datetime("America/Montreal"),
                  "%y/%m/%d -> %H:%M"
                ) %>
              </h3>
            </div>
            <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
              <form phx-submit="delete_tournament">
                <input type="hidden" name="tournament_id" value={tournament.id} />
                <button class="btn" type="submit">Delete</button>
              </form>
          </div>
          </div>

        <% end %>
      </div>
    </div>
    """
  end
end
