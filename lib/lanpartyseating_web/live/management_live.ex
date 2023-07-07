defmodule LanpartyseatingWeb.ManagementLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.SettingsLogic, as: SettingsLogic
  alias Lanpartyseating.StationLogic, as: StationLogic
  alias Lanpartyseating.ReservationLogic, as: ReservationLogic
  alias Lanpartyseating.PubSub, as: PubSub

  def mount(_params, _session, socket) do
    settings = SettingsLogic.get_settings()
    stations = StationLogic.get_all_stations()

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
      |> assign(:stations, stations)

    {:ok, socket}
  end

  defp broadcast_station_reservation(seat_number, reservation) do
    Phoenix.PubSub.broadcast(PubSub, "station_status", {:reserved, seat_number, reservation})
  end

  def handle_event(
        "reserve_seat",
        %{"seat_number" => seat_number, "duration" => duration, "badge_number" => badge_number},
        socket
      ) do
    case ReservationLogic.create_reservation(String.to_integer(seat_number), String.to_integer(duration), badge_number) do
      {:ok, updated} -> broadcast_station_reservation(String.to_integer(seat_number), updated)
    end

    {:noreply, socket}
  end

  def handle_event("cancel_seat", %{"station_id" => id, "station_number" => station_number, "cancel_reason" => reason}, socket) do
    ReservationLogic.cancel_reservation(id, reason)

    Phoenix.PubSub.broadcast(PubSub, "station_status", {:available, String.to_integer(station_number)})
    {:noreply, socket}
  end

  def handle_info({:available, seat_number}, socket) do
    new_stations =
      socket.assigns.stations
      |> Enum.map(fn s -> if s.station.station_number == seat_number, do: Map.merge(s, %{status: :available, reservation: nil}), else: s end)
    {:noreply, assign(socket, :stations, new_stations)}
  end

  def handle_info({:reserved, seat_number, reservation}, socket) do
    new_stations =
      socket.assigns.stations
      |> Enum.map(fn s -> if s.station.station_number == seat_number, do: Map.merge(s, %{status: :occupied, reservation: reservation}), else: s end)
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
                <ModalComponent.modal reservation={station_data.reservation} station={station_data.station} status={station_data.status}/>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
