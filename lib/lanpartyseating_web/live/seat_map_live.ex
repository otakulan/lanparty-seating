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
    <div
      class="relative min-h-screen overflow-hidden bg-[linear-gradient(180deg,#f5efe5_0%,#efe6d8_38%,#e9e1d5_100%)] text-[#21313c]"
      style="font-family: 'SF Pro Display', 'SF Pro Text', -apple-system, BlinkMacSystemFont, sans-serif;"
    >
      <div class="absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(255,255,255,0.78),transparent_34%),radial-gradient(circle_at_bottom_right,rgba(134,168,155,0.16),transparent_26%),linear-gradient(120deg,transparent_0%,rgba(255,255,255,0.35)_48%,transparent_100%)]">
      </div>

      <div class="relative h-screen p-4 md:p-6">
        <SeatMap.canvas id="interactive-seat-map" hook="SeatMapCanvas" payload={@map_payload} mode="view" class="h-full">
          <:toolbar>
            <div class="flex flex-wrap items-center gap-3 lg:gap-5">
              <div class="pr-1">
                <p class="text-[0.65rem] uppercase tracking-[0.32em] text-[#967552]">Interactive room map</p>
                <h1 class="text-[1.55rem] font-semibold tracking-[-0.04em] text-[#26333c]">LAN Party Seating</h1>
              </div>

              <div class="hidden h-10 w-px bg-[#ddd2c1] lg:block"></div>

              <div class="flex items-center gap-2">
                <button type="button" data-seat-map-command="zoom-out" class="btn btn-sm rounded-2xl border-0 bg-[#f3ece1] text-[#31424d] shadow-none hover:bg-[#eadfce]">-</button>
                <button type="button" data-seat-map-command="zoom-in" class="btn btn-sm rounded-2xl border-0 bg-[#f3ece1] text-[#31424d] shadow-none hover:bg-[#eadfce]">+</button>
                <button type="button" data-seat-map-command="reset-view" class="btn btn-sm rounded-2xl border-0 bg-[#2f4350] text-white shadow-none hover:bg-[#24343e]">Reset / Recentrer</button>
              </div>

              <SeatMap.legend class="hidden xl:flex" />
            </div>
          </:toolbar>

          <:details>
            <%= if @selected_seat do %>
              <div class="space-y-3">
                <div class="flex items-start justify-between gap-4">
                  <div>
                    <p class="text-[0.68rem] uppercase tracking-[0.28em] text-[#8d7357]">Poste / Seat</p>
                    <h2 class="text-4xl font-semibold tracking-[-0.05em] text-[#24313a]">{@selected_seat["label"]}</h2>
                  </div>
                  <span class="rounded-full bg-[#f4ece1] px-3 py-1.5 text-[0.68rem] font-semibold uppercase tracking-[0.18em] text-[#5c5043]">
                    {String.capitalize(@selected_seat["status"])}
                  </span>
                </div>

                <div class="grid grid-cols-2 gap-3 text-sm">
                  <div class="rounded-2xl bg-[#f7f2ea] px-3 py-2 text-[#55646d]">
                    <p class="text-[0.62rem] uppercase tracking-[0.22em] text-[#9a7d5d]">PC asset</p>
                    <p class="mt-1 font-semibold text-[#31414b]">{@selected_seat["pc_asset_code"]}</p>
                  </div>
                  <div class="rounded-2xl bg-[#f1f5f5] px-3 py-2 text-[#55646d]">
                    <p class="text-[0.62rem] uppercase tracking-[0.22em] text-[#6a8b87]">Host</p>
                    <p class="mt-1 truncate font-semibold text-[#31414b]">{@selected_seat["pc_hostname"]}</p>
                  </div>
                </div>

                <%= if @selected_seat["reservation_end_date"] do %>
                  <p class="rounded-2xl bg-[#fff6df] px-3 py-2 text-sm font-semibold text-[#8a5a0a]">
                    Reservee jusqu'a / Reserved until {format_iso_datetime(@selected_seat["reservation_end_date"])}
                  </p>
                <% else %>
                  <p class="rounded-2xl bg-[#f4f6f7] px-3 py-2 text-sm text-[#52616a]">Touchez un poste pour le detail / Tap any seat for details.</p>
                <% end %>
              </div>
            <% else %>
              <div class="space-y-3">
                <p class="text-[0.68rem] uppercase tracking-[0.28em] text-[#8d7357]">Carte interactive / Interactive map</p>
                <h2 class="text-[2rem] font-semibold leading-tight tracking-[-0.05em] text-[#24313a]">Touchez un poste pour voir son etat.</h2>
                <p class="text-sm leading-6 text-[#52616a]">Tap a station to inspect its state, countdown, and assigned PC, then pinch or scroll to explore the room.</p>
              </div>
            <% end %>
          </:details>
        </SeatMap.canvas>
      </div>
    </div>
    """
  end

  defp format_iso_datetime(iso_value) do
    case DateTime.from_iso8601(iso_value) do
      {:ok, datetime, _offset} -> format_datetime(datetime)
      _ -> iso_value
    end
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
