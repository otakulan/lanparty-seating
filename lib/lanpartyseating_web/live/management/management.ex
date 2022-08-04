defmodule LanpartyseatingWeb.ManagementControllerLive do
use Phoenix.LiveView

  def mount(_params, _session, socket) do
    settings = Lanpartyseating.SettingsLogic.get_settings()
    stations = Lanpartyseating.StationLogic.get_all_stations()
    Phoenix.PubSub.subscribe(Lanpartyseating.PubSub, "update_status")
    socket = socket
    |> assign(:columns, settings.columns)
    |> assign(:rows, settings.rows)
    |> assign(:col_trailing, settings.vertical_trailing)
    |> assign(:row_trailing, settings.horizontal_trailing)
    |> assign(:colpad, settings.column_padding)
    |> assign(:rowpad, settings.row_padding)
    |> assign(:table, stations)
    {:ok, socket}
  end

  def handle_event("reserve_seat", %{"seat_number" => seat_number, "duration" => duration, "badge_number" => badge_number}, socket) do
    resp = Lanpartyseating.ReservationLogic.create_reservation(seat_number, String.to_integer(duration), badge_number)

    socket = socket
    |> assign(:seat_number, String.to_integer(seat_number))
    |> assign(:duration, String.to_integer(duration))
    |> assign(:badge_number, badge_number)
    |> assign(:response, resp)

    {:noreply, socket}
  end

  def handle_event("cancel_seat", %{"seat_number" => seat_number, "cancel_reason" => reason}, socket) do
    socket = socket
    |> assign(:seat_number, String.to_integer(seat_number))
    |> assign(:reason, reason)
    {:noreply, socket}
  end

  def render(assigns) do
    # Phoenix.PubSub.subscribe(Lanpartyseating.PubSub, "update_status")
    Phoenix.View.render(LanpartyseatingWeb.ManagementView, "management.html", assigns)
  end

  # def handle_info({:update_status, status}, socket) do
  #   {:noreply, assign(socket, :status, status)}
  # end

  # defp broadcast_status(status) do
  #   Phoenix.PubSub.broadcast(Lanpartyseating.PubSub, "update_status", {:update_status, status})
  # end

end
