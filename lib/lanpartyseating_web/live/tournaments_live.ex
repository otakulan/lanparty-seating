defmodule LanpartyseatingWeb.TournamentsLive do
  require Logger
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.TournamentsLogic

  def mount(_params, _session, socket) do
    tournaments = TournamentsLogic.get_all_tournaments()

    socket =
      socket
      |> assign(:tournaments, tournaments)

    {:ok, socket}
  end

  def handle_event(
        "delete_tournament",
        %{"tournament_id" => tournament_id},
        socket
      ) do
    id = String.to_integer(tournament_id)

    TournamentsLogic.delete_tournament(id)

    socket =
      socket
      |> assign(:tournaments, TournamentsLogic.get_all_tournaments())

    {:noreply, socket}
  end

  def handle_event(
        "create_tournament",
        %{
          "name" => name,
          "start_time" => start_time,
          "duration" => duration,
          "start_station" => start_station,
          "end_station" => end_station,
        },
        socket
      ) do
    # Convering time string to UTC shifted TimeDate
    {:ok, naive_start_time} = Timex.parse(start_time, "{ISO:Extended:Z}")

    {:ok, local_start_time} =
      DateTime.from_naive(naive_start_time, "America/Toronto", Tzdata.TimeZoneDatabase)

    {:ok, utc_start_time} =
      DateTime.shift_zone(local_start_time, "Etc/UTC", Tzdata.TimeZoneDatabase)

    # Creating tournament
    {:ok, tournament} =
      TournamentsLogic.create_tournament(
        name,
        utc_start_time,
        String.to_integer(duration, 10)
      )

    # Creating station reservations for the tournament
    {:ok, _reservations} =
      TournamentsLogic.create_tournament_reservations_by_range(
        String.to_integer(start_station, 10),
        String.to_integer(end_station, 10),
        tournament.id
      )

    socket =
      socket
      |> assign(:tournaments, TournamentsLogic.get_all_tournaments())

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto max-w-5xl">
      <h1 class="text-3xl font-bold mb-2">Tournament Management</h1>
      <p class="text-base-content/60 mb-8">Schedule tournaments and reserve stations</p>
      
    <!-- Create Tournament Section -->
      <section class="mb-10">
        <h2 class="text-xl font-semibold mb-4 border-b border-base-300 pb-2">Create New Tournament</h2>
        <TournamentModalComponent.tournament_modal />
      </section>
      
    <!-- Tournaments List Section -->
      <section>
        <h2 class="text-xl font-semibold mb-4 border-b border-base-300 pb-2">Scheduled Tournaments</h2>

        <%= if Enum.empty?(@tournaments) do %>
          <p class="text-base-content/50 py-4">No tournaments scheduled yet.</p>
        <% else %>
          <div class="overflow-x-auto">
            <table class="table">
              <thead>
                <tr class="border-b-2 border-base-300">
                  <th class="text-base-content">Name</th>
                  <th class="text-base-content">Start Time</th>
                  <th class="text-base-content">End Time</th>
                  <th class="text-base-content">Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={tournament <- @tournaments} :key={tournament.id} class="hover:bg-base-200">
                  <td class="font-semibold">{tournament.name}</td>
                  <td>
                    {Calendar.strftime(
                      tournament.start_date |> Timex.to_datetime("America/Montreal"),
                      "%A %d %b - %H:%M"
                    )}
                  </td>
                  <td>
                    {Calendar.strftime(
                      tournament.end_date |> Timex.to_datetime("America/Montreal"),
                      "%A %d %b - %H:%M"
                    )}
                  </td>
                  <td>
                    <form phx-submit="delete_tournament">
                      <input type="hidden" name="tournament_id" value={tournament.id} />
                      <button class="btn btn-error btn-sm" type="submit">Delete</button>
                    </form>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </section>
    </div>
    """
  end
end
