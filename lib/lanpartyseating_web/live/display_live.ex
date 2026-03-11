defmodule LanpartyseatingWeb.DisplayLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.PubSub
  alias Lanpartyseating.TournamentsLogic
  alias Lanpartyseating.SettingsLogic
  alias Lanpartyseating.StationLogic
  alias Lanpartyseating.CarouselLogic

  defp assign_stations(socket, station_list) do
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
    settings = SettingsLogic.get_settings()
    {:ok, station_list} = StationLogic.get_all_stations()
    {:ok, tournaments} = TournamentsLogic.get_upcoming_tournaments()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "station_update")
      Phoenix.PubSub.subscribe(PubSub, "tournament_update")
      Phoenix.PubSub.subscribe(PubSub, "carousel_update")
    end

    carousel_images = CarouselLogic.list_images()

    socket =
      socket
      |> assign(:colpad, settings.column_padding)
      |> assign(:rowpad, settings.row_padding)
      |> assign_stations(station_list)
      |> assign(:tournaments, tournaments)
      |> assign(:carousel_images, carousel_images)

    {:ok, socket}
  end

  def handle_info({:tournaments, tournaments}, socket) do
    {:noreply, assign(socket, :tournaments, tournaments)}
  end

  def handle_info({:carousel, :updated}, socket) do
    {:noreply, assign(socket, :carousel_images, CarouselLogic.list_images())}
  end

  def handle_info({:stations, station_list}, socket) do
    # Reload settings in case padding/gaps changed
    settings = SettingsLogic.get_settings()

    socket =
      socket
      |> assign(:colpad, settings.column_padding)
      |> assign(:rowpad, settings.row_padding)
      |> assign_stations(station_list)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-row h-[calc(100vh-7rem)]">
      <div class="flex flex-col w-2/3 pr-5 overflow-y-auto">
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
                "
                @destroy="clearInterval(intervalId)"
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
        >
          <:cell :let={station_data}>
            <LanpartyseatingWeb.Components.DisplayModal.modal
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
                        tournament.start_date |> Timex.to_datetime("America/Toronto"),
                        "%A"
                      )}
                    </td>
                    <td class="font-mono">
                      {Calendar.strftime(
                        tournament.start_date |> Timex.to_datetime("America/Toronto"),
                        "%H:%M"
                      )}
                    </td>
                    <td class="font-mono">
                      {Calendar.strftime(
                        tournament.end_date |> Timex.to_datetime("America/Toronto"),
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
      <div class="flex flex-col grow pl-4 border-l border-base-300 overflow-hidden min-h-0">
        <h1 class="text-3xl font-bold mb-4">Games Available / Jeux disponibles</h1>

        <%= if @carousel_images != [] do %>
          <div
            id="game-carousel"
            class="flex-1 flex flex-col min-h-0"
            x-data={"{
              currentIndex: 0,
              total: #{length(@carousel_images)},
              intervalId: null,
              init() {
                if (this.total > 1) {
                  this.intervalId = setInterval(() => {
                    this.currentIndex = (this.currentIndex + 1) % this.total;
                  }, 2000);
                }
              },
              destroy() {
                if (this.intervalId) clearInterval(this.intervalId);
              }
            }"}
            @mouseenter="if (intervalId) { clearInterval(intervalId); intervalId = null; }"
            @mouseleave="if (total > 1) { intervalId = setInterval(() => { currentIndex = (currentIndex + 1) % total; }, 2000); }"
          >
            <%!-- Slides area — takes remaining space after dots --%>
            <div class="relative flex-1 min-h-0">
              <%= for {image, index} <- Enum.with_index(@carousel_images) do %>
                <div
                  class="absolute inset-0 flex flex-col items-center transition-opacity duration-700"
                  x-show={"currentIndex === #{index}"}
                  x-transition:enter="transition ease-out duration-700"
                  x-transition:enter-start="opacity-0"
                  x-transition:enter-end="opacity-100"
                  x-transition:leave="transition ease-in duration-500"
                  x-transition:leave-start="opacity-100"
                  x-transition:leave-end="opacity-0"
                >
                  <div class="flex-1 min-h-0 flex items-center justify-center w-full">
                    <img
                      src={~p"/carousel/images/#{image.id}"}
                      alt={image.title || "Game cover"}
                      class="max-w-full max-h-full object-contain rounded-lg shadow-lg"
                    />
                  </div>
                  <%= if image.title do %>
                    <p class="text-xl font-semibold mt-2 text-center flex-shrink-0">{image.title}</p>
                  <% end %>
                </div>
              <% end %>
            </div>

            <%!-- Dot indicators — in flow below the slides --%>
            <%= if length(@carousel_images) > 1 do %>
              <div class="flex justify-center gap-2 py-2 flex-shrink-0">
                <%= for {_image, index} <- Enum.with_index(@carousel_images) do %>
                  <button
                    class="w-3 h-3 rounded-full transition-colors"
                    x-bind:class={"currentIndex === #{index} ? 'bg-primary' : 'bg-base-content/30'"}
                    x-on:click={"currentIndex = #{index}"}
                  />
                <% end %>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="flex-1 flex items-center justify-center text-base-content/50">
            <p class="text-lg">No games configured / Aucun jeu configur&eacute;</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
