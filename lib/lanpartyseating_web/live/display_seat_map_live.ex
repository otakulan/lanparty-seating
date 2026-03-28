defmodule LanpartyseatingWeb.DisplaySeatMapLive do
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

    {:ok,
     socket
     |> assign(:page_title, "Display Seat Map")
     |> assign(:map_payload, payload)
     |> assign(:total_seats, total)
     |> assign(:available_seats, available)}
  end

  def handle_info({:seat_map_updated, _payload}, socket) do
    payload = load_published_payload()

    {:noreply,
     socket
     |> assign(:map_payload, payload)
     |> assign(:total_seats, Enum.count(payload.seats))
     |> assign(:available_seats, Enum.count(payload.seats, &(&1["status"] == "available")))}
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen bg-[#0d1117]">
      <div class="h-full p-3">
        <SeatMap.canvas
          id="kiosk-seat-map"
          hook="SeatMapKiosk"
          payload={@map_payload}
          mode="kiosk"
          class="h-full"
        >
          <:toolbar>
            <div class="flex items-center gap-4">
              <div>
                <div class="flex items-center gap-2">
                  <div class="h-2 w-2 rounded-full bg-[#22c55e] shadow-[0_0_8px_rgba(34,197,94,0.8)]"></div>
                  <span class="text-[0.6rem] uppercase tracking-[0.2em] text-[#8b949e]">Room Map</span>
                </div>
                <h1 class="text-2xl font-bold text-[#e6edf3]">LAN Party Seating</h1>
              </div>
              <div class="h-8 w-px bg-[#30363d]"></div>
              <div class="flex items-baseline gap-2">
                <span class="text-4xl font-bold text-[#22c55e]">{@available_seats}</span>
                <span class="text-sm uppercase tracking-[0.15em] text-[#8b949e]">available</span>
              </div>
              <div class="text-sm uppercase tracking-[0.15em] text-[#8b949e]">
                {@total_seats} seats
              </div>
            </div>
          </:toolbar>

          <:details>
            <div class="space-y-2">
              <div class="flex items-center gap-2">
                <div class="h-2 w-2 rounded-full bg-[#06b6d4] shadow-[0_0_8px_rgba(6,182,212,0.8)]"></div>
                <span class="text-[0.65rem] uppercase tracking-[0.2em] text-[#8b949e]">Status</span>
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
