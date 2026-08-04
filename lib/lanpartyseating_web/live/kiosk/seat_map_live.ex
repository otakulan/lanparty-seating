defmodule LanpartyseatingWeb.Kiosk.SeatMapLive do
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.PubSub
  alias Lanpartyseating.SeatMapsLogic
  alias LanpartyseatingWeb.Components.SeatMap

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "seat_map_update")
    end

    {payload, empty_state} = load_published_payload()
    total = if empty_state, do: 0, else: Enum.count(payload.seats)
    available = if empty_state, do: 0, else: Enum.count(payload.seats, &(&1.status == "available"))

    socket =
      socket
      |> assign(:page_title, "Kiosk Seat Map")
      |> assign(:map_payload, payload)
      |> assign(:empty_state, empty_state)
      |> assign(:total_seats, total)
      |> assign(:available_seats, available)

    socket = if connected?(socket) and not empty_state, do: push_event(socket, "seat_map_init", %{map: payload}), else: socket
    {:ok, socket}
  end

  def handle_info({:seat_map_updated, _payload}, socket) do
    {payload, empty_state} = load_published_payload()

    {:noreply,
      socket
      |> assign(:map_payload, payload)
      |> assign(:empty_state, empty_state)
      |> assign(:total_seats, if(empty_state, do: 0, else: Enum.count(payload.seats)))
      |> assign(:available_seats, if(empty_state, do: 0, else: Enum.count(payload.seats, &(&1.status == "available"))))
      |> then(fn s -> if empty_state, do: s, else: push_event(s, "seat_map_update", %{map: payload}) end)}
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
    <div class="h-screen bg-base-200">
      <div class="h-full p-3">
        <SeatMap.canvas
          id="kiosk-seat-map"
          hook="SeatMapKiosk"
          payload={@map_payload}
          mode="kiosk"
          class="h-full"
        >
          <:toolbar with_available_count={{@available_seats, @total_seats}}></:toolbar>

          <:details>
            <div class="space-y-2">
              <div class="flex items-center gap-2">
                <span class="text-xs uppercase tracking-wide text-base-content/60">Status</span>
              </div>
              <SeatMap.legend class="grid gap-1.5 [&>div]:justify-start" />
            </div>
          </:details>
        </SeatMap.canvas>
      </div>
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
