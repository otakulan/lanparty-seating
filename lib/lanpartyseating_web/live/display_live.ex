defmodule LanpartyseatingWeb.DisplayLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.PubSub, as: PubSub
  alias Lanpartyseating.TournamentsLogic, as: TournamentsLogic
  alias Lanpartyseating.SettingsLogic, as: SettingsLogic
  alias Lanpartyseating.StationLogic, as: StationLogic

  def mount(_params, _session, socket) do
    settings = SettingsLogic.get_settings()
    tournaments = TournamentsLogic.get_upcoming_tournaments()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "station_status")
    end

    socket =
      socket
      |> assign(:columns, settings.columns)
      |> assign(:rows, settings.rows)
      |> assign(:col_trailing, settings.vertical_trailing)
      |> assign(:row_trailing, settings.horizontal_trailing)
      |> assign(:colpad, settings.column_padding)
      |> assign(:rowpad, settings.row_padding)
      |> assign(:stations, StationLogic.get_all_stations())
      |> assign(:tournaments, tournaments)
      |> assign(:tournamentsCount, length(tournaments))

    {:ok, socket}
  end

  def handle_info({:available, seat_number}, socket) do
    new_stations =
      socket.assigns.stations
      |> Enum.map(fn s ->
        if s.station.station_number == seat_number,
          do: Map.merge(s, %{status: :available, reservation: nil}),
          else: s
      end)

    {:noreply, assign(socket, :stations, new_stations)}
  end

  def update_stations(old_stations, status, seat_number, reservation) do
    old_stations
    |> Enum.map(fn s ->
      if s.station.station_number == seat_number,
        do: Map.merge(s, %{status: status, reservation: reservation}),
        else: s
    end)
  end

  def handle_info({:occupied, seat_number, reservation}, socket) do
    new_stations = update_stations(socket.assigns.stations, :occupied, seat_number, reservation)

    {:noreply, assign(socket, :stations, new_stations)}
  end

  def handle_info({:reserved, seat_number, tournament_reservation}, socket) do
    new_stations =
      update_stations(socket.assigns.stations, :reserved, seat_number, tournament_reservation)

    {:noreply, assign(socket, :stations, new_stations)}
  end

  def render(assigns) do
    ~H"""
      <div class="flex flex-row">
        <div class="flex flex-col w-2/3 pr-5">
          <%!-- STATION MAP --%>
          <h1 style="font-size:30px">Stations</h1>
          <div class="flex flex-wrap w-full">
            <%= for r <- 0..(@rows-1) do %>
              <div class={"#{if rem(r,@rowpad) == rem(@row_trailing, @rowpad) and @rowpad != 1, do: "mb-4", else: ""} flex flex-row w-full "}>
                <%= for c <- 0..(@columns-1) do %>
                  <div class={"#{if rem(c,@colpad) == rem(@col_trailing, @colpad) and @colpad != 1, do: "mr-4", else: ""} flex flex-col h-14 flex-1 grow mx-1 "}>
                    <% station_data = assigns.stations |> Enum.at(r * @columns + c) %>
                    <%= if !is_nil(station_data) do %>
                    <DisplayModalComponent.modal reservation={station_data.reservation} station={station_data.station} status={station_data.status}/>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
          <%!-- TOURNAMENTS --%>
          <h1 style="font-size:30px">Upcoming Tournaments / Tournois à venir</h1>
          <div class="flex flex-wrap w-full">
            <div class="flex flex-row w-full border-b-4 " }>
              <div class="flex flex-col flex-1 mx-1 h-14 grow justify-center border-r-2" }>
                <h2><b>Name / Nom</b></h2>
              </div>
              <div class="flex flex-col flex-1 mx-1 h-14 grow justify-center border-r-2" }>
                <h2><b>Day / Jour</b></h2>
              </div>
              <div class="flex flex-col flex-1 mx-1 h-14 grow justify-center border-r-2" }>
                <h2><b>Start Time / Début</b></h2>
              </div>
              <div class="flex flex-col flex-1 mx-1 h-14 grow justify-center" }>
                <h2><b>End Time / Fin</b></h2>
              </div>
            </div>
            <%= for tournament <- @tournaments do %>
              <div class="flex flex-row w-full " }>
                <div class="flex flex-col flex-1 mx-1 h-10 grow justify-center border-r-2" }>
                  <h3><%= tournament.name %></h3>
                </div>
                <div class="flex flex-col flex-1 mx-1 h-10 grow justify-center border-r-2" }>
                  <h3>
                    <%= Calendar.strftime(
                      tournament.start_date |> Timex.to_datetime("America/Montreal"),
                      "%A"
                    ) %>
                  </h3>
                </div>
                <div class="flex flex-col flex-1 mx-1 h-10 grow justify-center border-r-2" }>
                  <h3>
                    <%= Calendar.strftime(
                      tournament.start_date |> Timex.to_datetime("America/Montreal"),
                      "%H:%M"
                    ) %>
                  </h3>
                </div>
                <div class="flex flex-col flex-1 mx-1 h-10 grow justify-center" }>
                  <h3>
                    <%= Calendar.strftime(
                      tournament.end_date |> Timex.to_datetime("America/Montreal"),
                      "%H:%M"
                    ) %>
                  </h3>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        <div class="flex flex-col grow">
          <h1 style="font-size:40px">Rules and Information</h1>
          <div class="flex flex-wrap">
            <ul class="list-disc pl-4"  style="font-size:19px">
              <li class="my-2"><b class="text-yellow-500">No spectators</b>. You need a reservation to be inside and to seat at a station</li>
              <li class="my-2"><b class="text-yellow-500">No free accounts</b>. You need to your own account to play games</li>
              <li class="my-2"><b class="text-yellow-500">No OSU</b> for music copyright reasons</li>
              <li class="my-2">
                <b class="text-yellow-500">Tournaments</b>:
                <ul class="list-disc pl-4" style="font-size:17px">
                  <li class="my-2">Complete teams will be prioritized</li>
                  <li class="my-2">Register your team or as a solo player at the info desk located at the room's entrance</li>
                  <li class="my-2">All tournaments are single elimination with prizes for the winning team</li>
                </ul>
              </li>

            </ul>
          </div>
          <h1 style="font-size:40px">Règlements et informations</h1>
          <div class="flex flex-wrap">
            <ul class="list-disc pl-4" style="font-size:19px">
              <li class="my-2"><b class="text-yellow-500">Pas de spectateurs</b>. Il est nécessaire de faire une réservation avant d'entrer dans la zone et de s'asseoir</li>
              <li class="my-2"><b class="text-yellow-500">Pas de comptes de jeu gratuit</b>. Vous devez posséder des comptes pour jouer aux jeux</li>
              <li class="my-2"><b class="text-yellow-500">Pas de OSU</b> pour des raisons de droits d'auteur</li>
              <li class="my-2">
                <b class="text-yellow-500">Tournois</b>:
                <ul class="list-disc pl-4" style="font-size:17px">
                  <li class="my-2">Les équipes complètes seront priorisées</li>
                  <li class="my-2">Enregistrez-vous ou votre équipe au bureau d'information à l'entrée de la salle</li>
                  <li class="my-2">Tous les tournois sont à élimination simple avec des prix pour l'équipe gagnante</li>
                </ul>
              </li>
            </ul>
          </div>
        </div>
      </div>
    """
  end
end
