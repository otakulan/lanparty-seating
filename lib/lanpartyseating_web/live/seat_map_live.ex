defmodule LanpartyseatingWeb.SeatMapLive do
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.PubSub
  alias Lanpartyseating.SeatMapsLogic
  alias LanpartyseatingWeb.Components.SeatMap
  alias LanpartyseatingWeb.Components.SeatDetailsModal

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "seat_map_update")
    end

    payload = load_published_payload()

    socket =
      socket
      |> assign(:page_title, "Seating")
      |> assign(:map_payload, payload)
      |> assign(:selected_seat, nil)
      |> assign(:show_modal, false)

    socket = if connected?(socket), do: push_event(socket, "seat_map_init", %{map: payload}), else: socket
    {:ok, socket}
  end

  def handle_event("seat_selected", %{"seat_slot_id" => seat_slot_id}, socket) do
    seat_slot_id = if is_binary(seat_slot_id), do: String.to_integer(seat_slot_id), else: seat_slot_id

    selected_seat =
      case SeatMapsLogic.get_seat_slot(seat_slot_id) do
        {:ok, seat} -> stringify_map(seat)
        _ -> nil
      end

    {:noreply, socket |> assign(:selected_seat, selected_seat) |> assign(:show_modal, true)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> assign(:show_modal, false)}
  end

  def handle_info({:seat_map_updated, _payload}, socket) do
    payload = load_published_payload()
    socket = socket
      |> assign(:map_payload, payload)
      |> push_event("seat_map_update", %{map: payload})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="h-dvh bg-base-200 flex flex-col">
      <div class="flex-1 p-3 md:p-4 min-h-0 relative">
        <SeatMap.canvas id="interactive-seat-map" hook="SeatMapCanvas" payload={@map_payload} mode="view" class="h-full" phx-ignore>
          <:toolbar with_zoom_buttons with_legend></:toolbar>
        </SeatMap.canvas>
      </div>

      <SeatDetailsModal.modal
        id="seat-modal"
        show={@show_modal}
        seat={@selected_seat}
        on_close="close_modal"
      />
    </div>
    """
  end

  defp load_published_payload do
    case SeatMapsLogic.get_map_payload("published") do
      {:ok, payload} -> payload
      _ -> %{width: 1920, height: 1080, meta: %{}, seats: [], objects: [], groups: [], team_assignments: []}
    end
  end

  defp stringify_map(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Map.new()
  end
end
