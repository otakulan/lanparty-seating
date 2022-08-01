defmodule LanpartyseatingWeb.DisplayControllerLive do
use Phoenix.LiveView

  def mount(_params, _session, socket) do
    stations = Lanpartyseating.StationLogic.get_all_stations()
    socket = socket
    |> assign(:columns, 10)
    |> assign(:rows, 4)
    |> assign(:col_trailing, 0)
    |> assign(:row_trailing, 0)
    |> assign(:colpad, 1)
    |> assign(:rowpad, 1)
    |> assign(:table, Enum.to_list(1..length(stations)))
    {:ok, socket}
  end

  def handle_event("reserve_seat", %{"seat_number" => seat_number, "duration" => duration, "badge_number" => badge_number}, socket) do
    socket = socket
    |> assign(:seat_number, String.to_integer(seat_number))
    |> assign(:duration, String.to_integer(duration))
    |> assign(:badge_number, badge_number)

    Lanpartyseating.ReservationLogic.create_reservation(seat_number, String.to_integer(duration), badge_number)

    {:noreply, socket}
  end

  def handle_event("cancel_seat", %{"seat_number" => seat_number, "cancel_reason" => reason}, socket) do
    socket = socket
    |> assign(:seat_number, String.to_integer(seat_number))
    |> assign(:reason, reason)
    {:noreply, socket}
  end

  def render(assigns) do
    Phoenix.View.render(LanpartyseatingWeb.DisplayView, "display.html", assigns)
  end

end
