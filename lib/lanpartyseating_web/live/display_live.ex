defmodule LanpartyseatingWeb.DisplayLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.PubSub, as: PubSub
  alias Lanpartyseating.TournamentsLogic, as: TournamentsLogic
  alias Lanpartyseating.SettingsLogic, as: SettingsLogic
  alias Lanpartyseating.StationLogic, as: StationLogic

  def mount(_params, _session, socket) do
    settings = SettingsLogic.get_settings()
    tournaments = TournamentsLogic.get_all_daily_tournaments()

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
    new_stations = update_stations(socket.assigns.stations, :reserved, seat_number, tournament_reservation)

    {:noreply, assign(socket, :stations, new_stations)}
  end

  def render(assigns) do
    ~H"""
    <div class="jumbotron">
      <h1 style="font-size:30px">Seats</h1>

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

      <h1 style="font-size:30px">Tournaments</h1>

      <div class="flex flex-wrap w-full">
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
        </div>
        <%= for tournament <- @tournaments do %>
          <div class="flex flex-row w-full" }>
            <div class="flex flex-col flex-1 mx-1 grow" }>
              <h3><%= tournament.name %></h3>
            </div>
            <div class="flex flex-col flex-1 mx-1 grow" }>
              <h3>
                <%= Calendar.strftime(
                  tournament.start_date |> Timex.to_datetime("America/Montreal"),
                  "%y/%m/%d -> %H:%M"
                ) %>
              </h3>
            </div>
            <div class="flex flex-col flex-1 mx-1 grow" }>
              <h3>
                <%= Calendar.strftime(
                  tournament.end_date |> Timex.to_datetime("America/Montreal"),
                  "%y/%m/%d -> %H:%M"
                ) %>
              </h3>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
