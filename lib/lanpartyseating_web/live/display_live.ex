defmodule LanpartyseatingWeb.DisplayLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.PubSub
  alias Lanpartyseating.SeatMapsLogic
  alias Lanpartyseating.SettingsLogic
  alias LanpartyseatingWeb.Components.SeatMap
  alias LanpartyseatingWeb.Components.SeatDetailsModal

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "seat_map_update")
    end

    {payload, empty_state} = load_published_payload()

    total = if empty_state, do: 0, else: Enum.count(payload.seats)
    available = if empty_state, do: 0, else: Enum.count(payload.seats, &(&1.status == "available"))

    settings = SettingsLogic.get_settings()
    seat_picking_enabled = Map.get(settings, :seat_picking_enabled_in_kiosk, false)

    socket =
      socket
      |> assign(:page_title, "Seating")
      |> assign(:map_payload, payload)
      |> assign(:empty_state, empty_state)
      |> assign(:total_seats, total)
      |> assign(:available_seats, available)
      |> assign(:selected_seat, nil)
      |> assign(:show_modal, false)
      |> assign(:pickable, seat_picking_enabled)

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

    {:noreply,
      socket
      |> assign(:map_payload, payload)
      |> assign(:empty_state, empty_state)
      |> assign(:total_seats, if(empty_state, do: 0, else: Enum.count(payload.seats)))
      |> assign(:available_seats, if(empty_state, do: 0, else: Enum.count(payload.seats, &(&1.status == "available"))))
      |> then(fn s -> if empty_state, do: s, else: push_event(s, "seat_map_update", %{map: payload}) end)}
  end

  def handle_params(_params, _uri, socket) do
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
    <div class="flex xl:flex-row flex-col gap-3 font-mono h-fill">
      <div class="xl:basis-3/4 grid grid-rows-1 grow min-h-120 bg-base-200">
        <SeatMap.canvas id="main-seat-map" hook="SeatMapKiosk" payload={@map_payload} mode="kiosk" pickable={@pickable} class="h-full">
          <:toolbar with_legend with_available_count={{@available_seats, @total_seats}}></:toolbar>

          <%!--
          <:details>
            <div class="space-y-2">
              <div class="flex items-center gap-1.5">
                <div class="h-2 w-2 rounded-full bg-info shadow-[0_0_8px_rgba(6,182,212,0.8)]"></div>
                <span class="text-tiny uppercase tracking-[0.18em] text-base-content/60">Statuts</span>
              </div>
              <SeatMap.legend class="grid gap-1 [&>div]:justify-start" />
            </div>
          </:details>
          --%>
        </SeatMap.canvas>
      </div>

      <div class="divider xl:divider-horizontal max-xl:divider-vertical m-0 shrink-0"></div>

      <%!-- Rules and information panel --%>
      <div class="xl:basis-1/4 bg-base-100 overflow-y-auto shrink-0">
        <div class="flex max-md:flex-col flex-row xl:flex-col gap-3">
          <div class="flex-1 min-w-0 xl:flex-none">
            <h2 class="text-xl font-bold text-base-content mb-1">
              <span>Règlements</span>
              <span></span>
            </h2>
            <h3 class="text-base text-base-content/60 mb-3">Rules and Information</h3>

            <ul class="space-y-2">
              <li class="rounded border border-error/50 bg-error/10 p-2">
                <p class="text-base font-semibold text-warning">Pas de spectateurs</p>
                <p class="text-sm text-error">No spectators</p>
                <p class="text-xs text-base-content/60 mt-1">Vous devez avoir une réservation pour être dans la zone.</p>
              </li>
              <li class="rounded border border-error/50 bg-error/10 p-2">
                <p class="text-base font-semibold text-warning">Pas de comptes gratuits</p>
                <p class="text-sm text-error">No free accounts</p>
                <p class="text-xs text-base-content/60 mt-1">Vous devez posséder vos propres comptes de jeu.</p>
              </li>
              <li class="rounded border border-error/50 bg-error/10 p-2">
                <p class="text-base font-semibold text-warning">Pas de OSU</p>
                <p class="text-sm text-error">No OSU</p>
                <p class="text-xs text-base-content/60 mt-1">Pour des raisons de droits d'auteur.</p>
              </li>
            </ul>
          </div>

          <div class="divider max-xl:divider-horizontal xl:divider-vertical m-0 shrink-0"></div>

          <div class="flex-1 min-w-0 xl:flex-none">
            <h2 class="text-xl font-bold text-base-content mb-1">Tournois</h2>
            <h3 class="text-base text-base-content/60 mb-3">Tournaments</h3>

            <ul class="space-y-1.5 text-sm">
              <li class="rounded border border-base-300 bg-base-200 p-2">
                <p class="text-base-content">Les équipes complètes seront priorisées</p>
                <p class="text-xs text-base-content/60">Complete teams will be prioritized</p>
              </li>
              <li class="rounded border border-base-300 bg-base-200 p-2">
                <p class="text-base-content">Enregistrez-vous au bureau d'information</p>
                <p class="text-xs text-base-content/60">Register at the info desk at the entrance</p>
              </li>
              <li class="rounded border border-base-300 bg-base-200 p-2">
                <p class="text-base-content">Élimination simple avec prix pour les gagnants</p>
                <p class="text-xs text-base-content/60">Single elimination with prizes for winners</p>
              </li>
            </ul>
          </div>
        </div>
      </div>

      <.live_component
        module={SeatDetailsModal}
        id="seat-modal-kiosk"
        show={@show_modal}
        seat={@selected_seat}
        on_close="close_modal"
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
