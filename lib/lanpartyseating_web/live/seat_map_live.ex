defmodule LanpartyseatingWeb.SeatMapLive do
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.PubSub
  alias Lanpartyseating.SeatMapsLogic
  alias LanpartyseatingWeb.Components.SeatMap

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "seat_map_update")
    end

    {:ok,
     socket
     |> assign(:page_title, "Seat Map")
     |> assign(:map_payload, load_published_payload())
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
    {:noreply, assign(socket, :map_payload, load_published_payload())}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0d1117]">
      <div class="h-screen p-3 md:p-4">
        <SeatMap.canvas id="interactive-seat-map" hook="SeatMapCanvas" payload={@map_payload} mode="view" class="h-full">
          <:toolbar>
            <div class="flex flex-wrap items-center gap-3">
              <div class="flex items-center gap-2">
                <div class="h-2 w-2 rounded-full bg-[#22c55e] shadow-[0_0_8px_rgba(34,197,94,0.8)]"></div>
                <div>
                  <p class="text-[0.6rem] uppercase tracking-[0.2em] text-[#8b949e]">Interactive</p>
                  <h1 class="text-lg font-bold text-[#e6edf3]">LAN Party Seating</h1>
                </div>
              </div>

              <div class="h-6 w-px bg-[#30363d]"></div>

              <div class="flex items-center gap-2">
                <button type="button" data-seat-map-command="zoom-out" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#8b949e] hover:bg-[#8b949e]/10">-</button>
                <button type="button" data-seat-map-command="zoom-in" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#8b949e] hover:bg-[#8b949e]/10">+</button>
                <button type="button" data-seat-map-command="reset-view" class="btn btn-sm border border-[#06b6d4] bg-[#06b6d4]/10 text-[#06b6d4] hover:bg-[#06b6d4]/20">Reset</button>
              </div>

              <SeatMap.legend class="hidden lg:flex" />
            </div>
          </:toolbar>

          <:details>
            <%= if @selected_seat do %>
              <div class="space-y-3">
                <div class="flex items-center justify-between gap-3">
                  <div>
                    <div class="flex items-center gap-2">
                      <div class="h-1.5 w-1.5 rounded-full bg-[#06b6d4]"></div>
                      <span class="text-[0.6rem] uppercase tracking-[0.2em] text-[#8b949e]">Seat</span>
                    </div>
                    <h2 class="text-3xl font-bold text-[#e6edf3]">{@selected_seat["label"]}</h2>
                  </div>
                  <span class={[
                    "rounded border px-2 py-1 text-xs font-mono uppercase tracking-wider",
                    status_classes(@selected_seat["status"])
                  ]}>
                    {status_text(@selected_seat["status"])}
                  </span>
                </div>

                <div class="grid grid-cols-2 gap-2">
                  <div class="rounded border border-[#30363d] bg-[#161b22] p-2">
                    <p class="text-[0.6rem] uppercase tracking-[0.15em] text-[#8b949e]">PC Asset</p>
                    <p class="font-mono text-[#22c55e]">{@selected_seat["pc_asset_code"]}</p>
                  </div>
                  <div class="rounded border border-[#30363d] bg-[#161b22] p-2">
                    <p class="text-[0.6rem] uppercase tracking-[0.15em] text-[#8b949e]">Host</p>
                    <p class="font-mono text-[#06b6d4] truncate">{@selected_seat["pc_hostname"]}</p>
                  </div>
                </div>

                <%= if @selected_seat["reservation_end_date"] do %>
                  <div class="rounded border border-[#f59e0b]/50 bg-[#f59e0b]/10 p-2">
                    <p class="text-xs text-[#fbbf24]">
                      Reserved until / Reservee jusqu'a {format_iso_datetime(@selected_seat["reservation_end_date"])}
                    </p>
                  </div>
                <% else %>
                  <div class="rounded border border-[#30363d] bg-[#161b22] p-2">
                    <p class="text-xs text-[#8b949e]">Tap a seat for details / Touchez un poste pour le detail</p>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="space-y-3">
                <div class="flex items-center gap-2">
                  <div class="h-2 w-2 rounded-full bg-[#06b6d4] shadow-[0_0_8px_rgba(6,182,212,0.8)]"></div>
                  <span class="text-[0.65rem] uppercase tracking-[0.2em] text-[#8b949e]">Interactive Map</span>
                </div>
                <h2 class="text-xl font-bold text-[#e6edf3]">Tap a seat to inspect</h2>
                <p class="text-xs text-[#8b949e]">
                  Tap any station to see its status, countdown, and assigned PC. Pinch or scroll to explore the room.
                </p>
              </div>
            <% end %>
          </:details>
        </SeatMap.canvas>
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

  defp status_text("available"), do: "Available"
  defp status_text("occupied"), do: "Occupied"
  defp status_text("reserved"), do: "Reserved"
  defp status_text("unavailable"), do: "Offline"
  defp status_text("tournament"), do: "Tournament"
  defp status_text(:available), do: "Available"
  defp status_text(:occupied), do: "Occupied"
  defp status_text(:reserved), do: "Reserved"
  defp status_text(:unavailable), do: "Offline"
  defp status_text(:tournament), do: "Tournament"
  defp status_text(status) when is_atom(status), do: status_text(Atom.to_string(status))
  defp status_text(status) when is_binary(status), do: String.capitalize(status)
  defp status_text(_), do: "Unknown"

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
