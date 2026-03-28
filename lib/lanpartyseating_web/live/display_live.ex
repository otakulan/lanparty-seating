defmodule LanpartyseatingWeb.DisplayLive do
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
     |> assign(:page_title, "LAN Party Seating")
     |> assign(:map_payload, payload)
     |> assign(:total_seats, total)
     |> assign(:available_seats, available)
     |> assign(:selected_seat, nil)}
  end

  def handle_event("seat_selected", %{"seat_slot_id" => seat_slot_id}, socket) do
    seat_slot_id = if is_binary(seat_slot_id), do: String.to_integer(seat_slot_id), else: seat_slot_id

    selected_seat =
      case SeatMapsLogic.get_seat_slot(seat_slot_id) do
        {:ok, seat} -> stringify_map(seat)
        _ -> nil
      end

    {:noreply, assign(socket, :selected_seat, selected_seat)}
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
    <div class="flex flex-row h-[calc(100vh-4rem)] bg-[#0d1117]" style="font-family: 'JetBrains Mono', 'SF Mono', ui-monospace, Menlo, monospace;">
      <div class="flex-1 p-2 min-w-0 overflow-hidden">
        <SeatMap.canvas id="main-seat-map" hook="SeatMapKiosk" payload={@map_payload} mode="kiosk" class="h-full">
          <:toolbar>
            <div class="flex flex-wrap items-center gap-2">
              <div class="flex items-center gap-2">
                <div class="h-2 w-2 rounded-full bg-[#22c55e] shadow-[0_0_8px_rgba(34,197,94,0.8)]"></div>
                <div>
                  <p class="text-[0.55rem] uppercase tracking-[0.18em] text-[#8b949e]">Status</p>
                  <h1 class="text-lg font-bold text-[#e6edf3]">LAN Party</h1>
                </div>
              </div>

              <div class="h-5 w-px bg-[#30363d]"></div>

              <div class="flex items-baseline gap-1.5">
                <span class="text-2xl font-bold text-[#22c55e]">{@available_seats}</span>
                <div class="flex flex-col">
                  <span class="text-sm font-semibold text-[#e6edf3]">disponibles</span>
                  <span class="text-xs text-[#8b949e]">available</span>
                </div>
              </div>

              <div class="text-sm text-[#8b949e]">
                <span class="font-semibold text-[#e6edf3]">{@total_seats}</span> postes / seats
              </div>

              <SeatMap.legend class="hidden lg:flex" />
            </div>
          </:toolbar>

          <:details>
            <div class="space-y-2">
              <div class="flex items-center gap-1.5">
                <div class="h-2 w-2 rounded-full bg-[#06b6d4] shadow-[0_0_8px_rgba(6,182,212,0.8)]"></div>
                <span class="text-[0.6rem] uppercase tracking-[0.18em] text-[#8b949e]">Statuts</span>
              </div>
              <SeatMap.legend class="grid gap-1 [&>div]:justify-start" />
            </div>
          </:details>
        </SeatMap.canvas>
      </div>

      <div class="w-72 border-l border-[#30363d] bg-[#161b22] p-3 overflow-y-auto flex-shrink-0">
        <h2 class="text-xl font-bold text-[#e6edf3] mb-1">Règlements</h2>
        <h3 class="text-base text-[#8b949e] mb-3">Rules and Information</h3>

        <ul class="space-y-2">
          <li class="rounded border border-[#ef4444]/50 bg-[#ef4444]/10 p-2">
            <p class="text-base font-semibold text-[#fbbf24]">Pas de spectateurs</p>
            <p class="text-sm text-[#f87171]">No spectators</p>
            <p class="text-xs text-[#8b949e] mt-1">Vous devez avoir une réservation pour être dans la zone.</p>
          </li>
          <li class="rounded border border-[#ef4444]/50 bg-[#ef4444]/10 p-2">
            <p class="text-base font-semibold text-[#fbbf24]">Pas de comptes gratuits</p>
            <p class="text-sm text-[#f87171]">No free accounts</p>
            <p class="text-xs text-[#8b949e] mt-1">Vous devez posséder vos propres comptes de jeu.</p>
          </li>
          <li class="rounded border border-[#ef4444]/50 bg-[#ef4444]/10 p-2">
            <p class="text-base font-semibold text-[#fbbf24]">Pas de OSU</p>
            <p class="text-sm text-[#f87171]">No OSU</p>
            <p class="text-xs text-[#8b949e] mt-1">Pour des raisons de droits d'auteur.</p>
          </li>
        </ul>

        <h2 class="text-xl font-bold text-[#e6edf3] mt-4 mb-1">Tournois</h2>
        <h3 class="text-base text-[#8b949e] mb-3">Tournaments</h3>

        <ul class="space-y-1.5 text-sm">
          <li class="rounded border border-[#30363d] bg-[#0d1117] p-2">
            <p class="text-[#e6edf3]">Les équipes complètes seront priorisées</p>
            <p class="text-xs text-[#8b949e]">Complete teams will be prioritized</p>
          </li>
          <li class="rounded border border-[#30363d] bg-[#0d1117] p-2">
            <p class="text-[#e6edf3]">Enregistrez-vous au bureau d'information</p>
            <p class="text-xs text-[#8b949e]">Register at the info desk at the entrance</p>
          </li>
          <li class="rounded border border-[#30363d] bg-[#0d1117] p-2">
            <p class="text-[#e6edf3]">Élimination simple avec prix pour les gagnants</p>
            <p class="text-xs text-[#8b949e]">Single elimination with prizes for winners</p>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  defp status_classes("available"), do: "border-[#22c55e] bg-[#22c55e]/10 text-[#4ade80]"
  defp status_classes("occupied"), do: "border-[#f59e0b] bg-[#f59e0b]/10 text-[#fbbf24]"
  defp status_classes("reserved"), do: "border-[#6b7280] bg-[#6b7280]/10 text-[#9ca3af]"
  defp status_classes("unavailable"), do: "border-[#ef4444] bg-[#ef4444]/10 text-[#f87171]"
  defp status_classes("tournament"), do: "border-[#06b6d4] bg-[#06b6d4]/10 text-[#22d3ee]"
  defp status_classes(_), do: "border-[#30363d] bg-[#161b22] text-[#8b949e]"

  defp status_text("available"), do: "Disponible"
  defp status_text("occupied"), do: "Occupé"
  defp status_text("reserved"), do: "Réservé"
  defp status_text("unavailable"), do: "Hors service"
  defp status_text("tournament"), do: "Tournoi"
  defp status_text(status), do: String.capitalize(status)

  defp format_iso_datetime(iso_value) do
    case DateTime.from_iso8601(iso_value) do
      {:ok, datetime, _offset} -> format_time_only(datetime)
      _ -> iso_value
    end
  end

  defp format_time_only(datetime) do
    Calendar.strftime(datetime, "%H:%M")
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
