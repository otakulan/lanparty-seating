defmodule LanpartyseatingWeb.DisplayLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.PubSub, as: PubSub
  alias Lanpartyseating.TournamentsLogic, as: TournamentsLogic
  alias Lanpartyseating.SettingsLogic, as: SettingsLogic
  alias Lanpartyseating.StationLogic, as: StationLogic

  def assign_stations(socket, station_list) do
    {stations, {columns, rows}} = StationLogic.stations_by_xy(station_list)

    # Calculate stats for "next available" indicator
    station_values = Map.values(stations)
    total_stations = length(station_values)
    available_count = Enum.count(station_values, fn s -> s.status == :available end)

    # Find next available station (earliest end_date among occupied)
    next_available =
      station_values
      |> Enum.filter(fn s -> s.status == :occupied and length(s.station.reservations) > 0 end)
      |> Enum.map(fn s ->
        reservation = List.first(s.station.reservations)
        %{station_number: s.station.station_number, end_date: reservation.end_date}
      end)
      |> Enum.min_by(fn r -> DateTime.to_unix(r.end_date) end, fn -> nil end)

    socket
    |> assign(:columns, columns)
    |> assign(:rows, rows)
    |> assign(:stations, stations)
    |> assign(:total_stations, total_stations)
    |> assign(:available_count, available_count)
    |> assign(:next_available, next_available)
  end

  def mount(_params, _session, socket) do
    {:ok, settings} = SettingsLogic.get_settings()
    {:ok, station_list} = StationLogic.get_all_stations()
    {:ok, tournaments} = TournamentsLogic.get_upcoming_tournaments()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "station_update")
      Phoenix.PubSub.subscribe(PubSub, "tournament_update")
    end

    socket =
      socket
      |> assign(:col_trailing, settings.vertical_trailing)
      |> assign(:row_trailing, settings.horizontal_trailing)
      |> assign(:colpad, settings.column_padding)
      |> assign(:rowpad, settings.row_padding)
      |> assign_stations(station_list)
      |> assign(:tournaments, tournaments)

    {:ok, socket}
  end

  def handle_info({:tournaments, tournaments}, socket) do
    {:noreply, assign(socket, :tournaments, tournaments)}
  end

  def handle_info({:stations, station_list}, socket) do
    {:noreply, assign_stations(socket, station_list)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-row">
      <div class="flex flex-col w-2/3 pr-5">
        <%!-- STATION MAP --%>
        <div class="flex items-center justify-between mb-2">
          <h1 class="text-3xl font-bold">Stations</h1>
          <%= if @available_count > 0 do %>
            <div class="text-sm text-base-content/70">
              {@available_count} / {@total_stations} available
            </div>
          <% else %>
            <%= if @next_available do %>
              <div
                id={"next-available-#{DateTime.to_unix(@next_available.end_date)}"}
                class="text-sm text-base-content/70"
                x-data={"{ endTime: new Date('#{DateTime.to_iso8601(@next_available.end_date)}'), remaining: '', intervalId: null }"}
                x-init="
                  const update = () => {
                    const now = new Date();
                    const diff = Math.max(0, endTime - now);
                    const mins = Math.floor(diff / 60000);
                    const secs = Math.floor((diff % 60000) / 1000);
                    if (mins > 0) {
                      remaining = mins + 'm' + secs + 's';
                    } else {
                      remaining = secs + 's';
                    }
                  };
                  update();
                  intervalId = setInterval(update, 1000);
                  $cleanup(() => clearInterval(intervalId));
                "
              >
                Next available: <span class="font-bold">Station {@next_available.station_number}</span> in <span class="font-mono font-bold" x-text="remaining"></span>
              </div>
            <% else %>
              <div class="text-sm text-base-content/70">
                No stations available
              </div>
            <% end %>
          <% end %>
        </div>

        <%!-- LEGEND --%>
        <.station_legend />

        <.station_grid
          stations={@stations}
          rows={@rows}
          columns={@columns}
          rowpad={@rowpad}
          colpad={@colpad}
          row_trailing={@row_trailing}
          col_trailing={@col_trailing}
        >
          <:cell :let={station_data}>
            <DisplayModalComponent.modal
              reservation={station_data.reservation}
              station={station_data.station}
              status={station_data.status}
            />
          </:cell>
        </.station_grid>

        <%!-- TOURNAMENTS --%>
        <h1 class="text-2xl font-bold mt-6 mb-3">Upcoming Tournaments / Tournois à venir</h1>

        <%!-- Next tournament countdown --%>
        <%= if length(@tournaments) > 0 do %>
          <% next_tournament = List.first(@tournaments) %>
          <div class="p-4 mb-4 bg-base-200 rounded-lg">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-sm text-base-content/70">Next Tournament / Prochain Tournoi</div>
                <div class="text-xl font-bold">{next_tournament.name}</div>
              </div>
              <div class="text-right">
                <div class="text-sm text-base-content/70">Starts in / Commence dans</div>
                <.countdown_long start_date={next_tournament.start_date} class="countdown-timer" />
              </div>
            </div>
          </div>
        <% end %>

        <%= if length(@tournaments) > 0 do %>
          <div class="overflow-x-auto border border-base-300 rounded-lg">
            <table class="table">
              <thead>
                <tr class="bg-base-200">
                  <th class="text-base-content font-semibold">Name / Nom</th>
                  <th class="text-base-content font-semibold">Day / Jour</th>
                  <th class="text-base-content font-semibold">Start / Début</th>
                  <th class="text-base-content font-semibold">End / Fin</th>
                </tr>
              </thead>
              <tbody>
                <%= for tournament <- @tournaments do %>
                  <tr class="hover:bg-base-200/50">
                    <td class="font-medium">{tournament.name}</td>
                    <td>
                      {Calendar.strftime(
                        tournament.start_date |> Timex.to_datetime("America/Montreal"),
                        "%A"
                      )}
                    </td>
                    <td class="font-mono">
                      {Calendar.strftime(
                        tournament.start_date |> Timex.to_datetime("America/Montreal"),
                        "%H:%M"
                      )}
                    </td>
                    <td class="font-mono">
                      {Calendar.strftime(
                        tournament.end_date |> Timex.to_datetime("America/Montreal"),
                        "%H:%M"
                      )}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <p class="text-base-content/50 py-4">No upcoming tournaments / Aucun tournoi à venir</p>
        <% end %>
      </div>
      <div class="flex flex-col grow pl-4 border-l border-base-300">
        <h1 class="text-3xl font-bold mb-4">Rules and Information</h1>
        <ul class="list-disc pl-5 space-y-2 text-lg">
          <li>
            <b class="text-warning">No spectators</b>. You need a reservation to be inside and to seat at a station
          </li>
          <li>
            <b class="text-warning">No free accounts</b>. You need to your own account to play games
          </li>
          <li><b class="text-warning">No OSU</b> for music copyright reasons</li>
          <li>
            <b class="text-warning">Tournaments</b>:
            <ul class="list-disc pl-5 mt-1 space-y-1 text-base">
              <li>Complete teams will be prioritized</li>
              <li>Register your team or as a solo player at the info desk located at the room's entrance</li>
              <li>All tournaments are single elimination with prizes for the winning team</li>
            </ul>
          </li>
        </ul>

        <h1 class="text-3xl font-bold mt-8 mb-4">Règlements et informations</h1>
        <ul class="list-disc pl-5 space-y-2 text-lg">
          <li>
            <b class="text-warning">Pas de spectateurs</b>. Il est nécessaire de faire une réservation avant d'entrer dans la zone et de s'asseoir
          </li>
          <li>
            <b class="text-warning">Pas de comptes de jeu gratuit</b>. Vous devez posséder des comptes pour jouer aux jeux
          </li>
          <li>
            <b class="text-warning">Pas de OSU</b> pour des raisons de droits d'auteur
          </li>
          <li>
            <b class="text-warning">Tournois</b>:
            <ul class="list-disc pl-5 mt-1 space-y-1 text-base">
              <li>Les équipes complètes seront priorisées</li>
              <li>Enregistrez-vous ou votre équipe au bureau d'information à l'entrée de la salle</li>
              <li>Tous les tournois sont à élimination simple avec des prix pour l'équipe gagnante</li>
            </ul>
          </li>
        </ul>
      </div>
    </div>
    """
  end
end
