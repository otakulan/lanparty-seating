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

    {payload, empty_state} = load_published_payload()

    socket =
      socket
      |> assign(:page_title, "Seating")
      |> assign(:map_payload, payload)
      |> assign(:empty_state, empty_state)
      |> assign(:selected_seat, nil)
      |> assign(:show_modal, false)

    socket = if connected?(socket) and not empty_state, do: push_event(socket, "seat_map_init", %{map: payload}), else: socket
    {:ok, socket}
  end

  def handle_event("seat_selected", %{"seat_slot_id" => seat_slot_id}, socket) do
    seat_slot_id = if is_binary(seat_slot_id), do: String.to_integer(seat_slot_id), else: seat_slot_id

    selected_seat =
      case SeatMapsLogic.get_seat_slot(seat_slot_id) do
        {:ok, seat} -> seat
        _ -> nil
      end

    {:noreply, socket |> assign(:selected_seat, selected_seat) |> assign(:show_modal, true)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, close_modal(socket)}
  end

  def handle_info({:seat_reserved, _seat_slot_id}, socket) do
    {:noreply,
      socket
      |> put_flash(:info, "Poste réservé / Seat reserved")
      |> close_modal()}
  end

  def handle_info({:seat_map_updated, _payload}, socket) do
    {payload, empty_state} = load_published_payload()
    socket = socket
      |> assign(:map_payload, payload)
      |> assign(:empty_state, empty_state)
      |> then(fn s -> if empty_state, do: s, else: push_event(s, "seat_map_update", %{map: payload}) end)
    {:noreply, socket}
  end

  defp close_modal(socket) do
    socket |> assign(:show_modal, false) |> assign(:selected_seat, nil)
  end

  def render(assigns) do
    ~H"""
    <%= if @empty_state do %>
      <div class="flex items-center justify-center h-full">
        <div class="text-center">
          <h2 class="text-2xl font-bold text-base-content mb-2">No map published / Aucune carte publiée</h2>
          <p class="text-base-content/60">Create and publish a Seat Map to display it here. / Créez et publiez une carte pour l'afficher ici.</p>
        </div>
      </div>
    <% else %>
    <div class="h-fill bg-base-200 flex flex-col">
      <div class="flex-1 p-3 md:p-4 min-h-0 relative">
        <SeatMap.canvas id="interactive-seat-map" hook="SeatMapCanvas" payload={@map_payload} mode="view" class="h-full">
          <:toolbar with_zoom_buttons with_legend></:toolbar>
        </SeatMap.canvas>
      </div>

      <.live_component
        module={SeatDetailsModal}
        id="seat-modal"
        show={@show_modal}
        seat={@selected_seat}
        on_close="close_modal"
        badge_input
      />
    </div>
    <% end %>
    """
  end

  defp load_published_payload do
    case SeatMapsLogic.get_map_payload() do
      {:ok, payload} -> {payload, false}
      {:error, _} -> {%{width: 1920, height: 1080, meta: %{}, seats: [], objects: []}, true}
    end
  end
end
