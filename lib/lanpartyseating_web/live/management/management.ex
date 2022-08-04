defmodule LanpartyseatingWeb.ManagementControllerLive do
use Phoenix.LiveView
  alias Lanpartyseating.SettingsLogic, as: SettingsLogic
  alias Lanpartyseating.StationLogic, as: StationLogic
  alias Lanpartyseating.ReservationLogic, as: ReservationLogic
  alias Lanpartyseating.PubSub, as: PubSub

  def mount(_params, _session, socket) do
    settings = SettingsLogic.get_settings()
    stations = StationLogic.get_all_stations()

    Phoenix.PubSub.subscribe(PubSub, "update_stations")

    socket = socket
    |> assign(:columns, settings.columns)
    |> assign(:rows, settings.rows)
    |> assign(:col_trailing, settings.vertical_trailing)
    |> assign(:row_trailing, settings.horizontal_trailing)
    |> assign(:colpad, settings.column_padding)
    |> assign(:rowpad, settings.row_padding)
    |> assign(:stations, stations)

    {:ok, socket}
  end

  def handle_event("reserve_seat", %{"seat_number" => seat_number, "duration" => duration, "badge_number" => badge_number}, socket) do
    ReservationLogic.create_reservation(seat_number, String.to_integer(duration), badge_number)

    stations = StationLogic.get_all_stations()
    broadcast_stations(stations)

    {:noreply, socket}
  end

  def handle_event("cancel_seat", %{"station_id" => id, "cancel_reason" => reason}, socket) do
    ReservationLogic.cancel_reservation(id, reason)

    stations = StationLogic.get_all_stations()
    broadcast_stations(stations)

    {:noreply, socket}
  end

  def render(assigns) do
    Phoenix.PubSub.subscribe(PubSub, "update_stations")

    Phoenix.View.render(LanpartyseatingWeb.ManagementView, "management.html", assigns)
  end

  def handle_info({:update_stations, stations}, socket) do
    {:noreply, assign(socket, :stations, stations)}
  end

  defp broadcast_stations(stations) do
    Phoenix.PubSub.broadcast(PubSub, "update_stations", {:update_stations, stations})
  end

end
