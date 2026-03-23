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
    <div
      class="min-h-screen overflow-hidden bg-[linear-gradient(180deg,#1b2a32_0%,#213841_42%,#172126_100%)] text-white"
      style="font-family: 'SF Pro Display', 'SF Pro Text', -apple-system, BlinkMacSystemFont, sans-serif;"
    >
      <div class="h-screen p-4 md:p-6">
        <SeatMap.canvas
          id="kiosk-seat-map"
          hook="SeatMapCanvas"
          payload={@map_payload}
          mode="kiosk"
          class="h-full border-white/10 bg-[radial-gradient(circle_at_top,#355c66_0%,#21343b_40%,#172126_100%)] shadow-[0_24px_80px_rgba(0,0,0,0.3)]"
        >
          <:toolbar>
            <div class="flex flex-wrap items-center gap-5 text-[#31424d]">
              <div>
                <p class="text-[0.65rem] uppercase tracking-[0.28em] text-[#9b7b53]">Carte salle / Room map</p>
                <h1 class="text-[2rem] font-semibold tracking-[-0.05em] text-[#24313a]">LAN Party Seating</h1>
              </div>
              <div class="h-10 w-px bg-[#d9cfbe]"></div>
              <div class="text-sm text-[#5b6b75]">
                <span class="font-semibold text-4xl tracking-[-0.06em] text-[#24313a]">{@available_seats}</span>
                <span class="ml-2 uppercase tracking-[0.18em] text-[#9b7b53]">libres / available</span>
              </div>
              <div class="text-sm uppercase tracking-[0.18em] text-[#9b7b53]">{@total_seats} postes / seats</div>
            </div>
          </:toolbar>

          <:details>
            <div class="space-y-3 text-[#31424d]">
              <p class="text-[0.68rem] uppercase tracking-[0.28em] text-[#9b7b53]">Statuts / Status</p>
              <SeatMap.legend class="grid gap-2 [&>div]:justify-start" />
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
