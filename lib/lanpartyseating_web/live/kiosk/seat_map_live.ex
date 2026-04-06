defmodule LanpartyseatingWeb.Kiosk.SeatMapLive do
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.PubSub
  alias Lanpartyseating.SeatMapsLogic
  alias LanpartyseatingWeb.Components.SeatMap

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "seat_map_update")
    end

    payload = load_published_payload()
    total = Enum.count(payload.seats)
    available = Enum.count(payload.seats, &(&1["status"] == "available"))

    socket =
      socket
      |> assign(:page_title, "Kiosk Seat Map")
      |> assign(:map_payload, payload)
      |> assign(:total_seats, total)
      |> assign(:available_seats, available)

    socket = if connected?(socket), do: push_event(socket, "seat_map_init", %{map: payload}), else: socket
    {:ok, socket}
  end

  def handle_info({:seat_map_updated, _payload}, socket) do
    payload = load_published_payload()

    {:noreply,
     socket
     |> assign(:map_payload, payload)
     |> assign(:total_seats, Enum.count(payload.seats))
     |> assign(:available_seats, Enum.count(payload.seats, &(&1["status"] == "available")))
     |> push_event("seat_map_update", %{map: payload})}
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen bg-base-200">
      <div class="h-full p-3">
        <SeatMap.canvas
          id="kiosk-seat-map"
          hook="SeatMapKiosk"
          payload={@map_payload}
          mode="kiosk"
          class="h-full"
        >
          <:toolbar>
            <div class="flex items-baseline gap-1">
              <span class="text-4xl font-bold text-success">{@available_seats}</span>
              <div class="flex flex-col leading-tight">
                <span class="text-sm font-semibold text-base-content">disponibles</span>
                <span class="text-xs text-base-content/60">available</span>
              </div>
            </div>
            <div class="text-sm text-base-content/60">
              <span class="font-semibold text-base-content">{@total_seats}</span> postes / seats
            </div>
          </:toolbar>

          <:details>
            <div class="space-y-2">
              <div class="flex items-center gap-2">
                <div class="h-2 w-2 rounded-full bg-info shadow-[0_0_8px_rgba(6,182,212,0.8)]"></div>
                <span class="text-tiny uppercase tracking-[0.2em] text-base-content/60">Status</span>
              </div>
              <SeatMap.legend class="grid gap-1.5 [&>div]:justify-start" />
            </div>
          </:details>
        </SeatMap.canvas>
      </div>
    </div>
    """
  end

  defp load_published_payload do
    case SeatMapsLogic.get_map_payload("published") do
      {:ok, payload} -> payload
      _ -> %{width: 1920, height: 1080, meta: %{}, seats: [], objects: [], groups: [], team_assignments: []}
    end
  end
end
