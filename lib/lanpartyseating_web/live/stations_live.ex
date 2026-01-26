defmodule LanpartyseatingWeb.StationsLive do
  @moduledoc """
  Unified station management page that combines self-service reservation
  with admin station management.

  Public users can:
  - View station availability
  - Reserve available stations (45-minute session)

  Admin actions (require authentication or sudo badge scan):
  - Extend reservations
  - Cancel reservations
  - Mark stations as broken
  - Re-open broken stations

  ## Modal Architecture

  This page uses LiveView-controlled modal visibility (via CSS class `modal-open`)
  instead of the browser's native `showModal()` API. This approach:
  - Avoids browser top-layer corruption issues
  - Integrates properly with LiveView's DOM patching
  - Maintains DaisyUI styling
  - Supports focus trapping via the focus_wrap hook
  """
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.Accounts
  alias Lanpartyseating.SettingsLogic
  alias Lanpartyseating.StationLogic
  alias Lanpartyseating.ReservationLogic
  alias Lanpartyseating.PubSub
  alias LanpartyseatingWeb.Components.StationModal

  # ============================================================================
  # Mount & Initial State
  # ============================================================================

  def mount(_params, _session, socket) do
    {:ok, settings} = SettingsLogic.get_settings()
    {:ok, station_list} = StationLogic.get_all_stations()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "station_status")
      Phoenix.PubSub.subscribe(PubSub, "station_update")
    end

    socket =
      socket
      |> assign(:colpad, settings.column_padding)
      |> assign(:rowpad, settings.row_padding)
      |> assign_stations(station_list)
      |> assign(:registration_error, nil)
      # Station modal state
      |> assign(:show_station_modal, false)
      |> assign(:selected_station, nil)
      # Sudo modal state
      |> assign(:show_sudo_modal, false)
      |> assign(:pending_action, nil)
      |> assign(:sudo_error, nil)

    {:ok, socket}
  end

  defp assign_stations(socket, station_list) do
    {stations, {columns, rows}} = StationLogic.stations_by_xy(station_list)

    socket
    |> assign(:columns, columns)
    |> assign(:rows, rows)
    |> assign(:stations, stations)
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp admin_authenticated?(socket) do
    scope = socket.assigns[:current_scope]
    scope != nil && scope.user != nil
  end

  defp find_station_data(stations, station_number) do
    Enum.find(Map.values(stations), fn s ->
      s.station.station_number == station_number
    end)
  end

  defp format_pending_action(nil), do: ""

  defp format_pending_action(%{event: event, params: params}) do
    station = params["station_number"]

    case event do
      "extend_reservation" ->
        minutes = params["minutes_increment"]
        "Extend station #{station} by #{minutes} minutes / Prolonger la station #{station} de #{minutes} minutes"

      "cancel_station" ->
        "Cancel reservation at station #{station} / Annuler la réservation à la station #{station}"

      "close_station" ->
        "Mark station #{station} as broken / Marquer la station #{station} comme brisée"

      "open_station" ->
        "Re-open station #{station} / Rouvrir la station #{station}"

      _ ->
        "Unknown action"
    end
  end

  # ============================================================================
  # Modal Control Events
  # ============================================================================

  def handle_event("open_station_modal", %{"station" => station_number}, socket) do
    station_number = String.to_integer(station_number)
    station_data = find_station_data(socket.assigns.stations, station_number)

    {:noreply,
     socket
     |> assign(:selected_station, station_data)
     |> assign(:show_station_modal, true)
     |> assign(:registration_error, nil)}
  end

  def handle_event("close_station_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_station, nil)
     |> assign(:show_station_modal, false)
     |> assign(:registration_error, nil)}
  end

  def handle_event("close_sudo_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_sudo_modal, false)
     |> assign(:pending_action, nil)
     |> assign(:sudo_error, nil)}
  end

  # ============================================================================
  # Public Events (no sudo required)
  # ============================================================================

  def handle_event("reserve_station", %{"station_number" => station_number, "uid" => uid}, socket) do
    case ReservationLogic.create_reservation(String.to_integer(station_number), 45, uid) do
      {:error, error} ->
        {:noreply, assign(socket, :registration_error, error)}

      {:ok, _reservation} ->
        {:noreply,
         socket
         |> assign(:registration_error, nil)
         |> assign(:show_station_modal, false)
         |> assign(:selected_station, nil)}
    end
  end

  # ============================================================================
  # Admin Events (sudo required if not authenticated)
  # ============================================================================

  def handle_event("extend_reservation", params, socket) do
    if admin_authenticated?(socket) do
      do_extend_reservation(params, socket)
    else
      {:noreply, request_sudo(socket, "extend_reservation", params)}
    end
  end

  def handle_event("cancel_station", params, socket) do
    if admin_authenticated?(socket) do
      do_cancel_station(params, socket)
    else
      {:noreply, request_sudo(socket, "cancel_station", params)}
    end
  end

  def handle_event("close_station", params, socket) do
    if admin_authenticated?(socket) do
      do_close_station(params, socket)
    else
      {:noreply, request_sudo(socket, "close_station", params)}
    end
  end

  def handle_event("open_station", params, socket) do
    if admin_authenticated?(socket) do
      do_open_station(params, socket)
    else
      {:noreply, request_sudo(socket, "open_station", params)}
    end
  end

  # ============================================================================
  # Sudo Modal Events
  # ============================================================================

  def handle_event("verify_sudo", %{"badge_number" => badge_number}, socket) do
    case Accounts.get_enabled_admin_badge(badge_number) do
      nil ->
        {:noreply, assign(socket, :sudo_error, "Invalid or disabled badge / Badge invalide ou désactivé")}

      _badge ->
        # Badge verified - close modal and execute the pending action
        %{event: event, params: params} = socket.assigns.pending_action

        socket =
          socket
          |> assign(:pending_action, nil)
          |> assign(:sudo_error, nil)
          |> assign(:show_sudo_modal, false)

        execute_action(event, params, socket)
    end
  end

  # ============================================================================
  # Action Execution
  # ============================================================================

  defp request_sudo(socket, event, params) do
    socket
    |> assign(:pending_action, %{event: event, params: params})
    |> assign(:sudo_error, nil)
    |> assign(:show_station_modal, false)
    |> assign(:selected_station, nil)
    |> assign(:show_sudo_modal, true)
  end

  defp execute_action("extend_reservation", params, socket), do: do_extend_reservation(params, socket)
  defp execute_action("cancel_station", params, socket), do: do_cancel_station(params, socket)
  defp execute_action("close_station", params, socket), do: do_close_station(params, socket)
  defp execute_action("open_station", params, socket), do: do_open_station(params, socket)

  defp do_extend_reservation(%{"station_number" => id, "minutes_increment" => minutes}, socket) do
    case ReservationLogic.extend_reservation(String.to_integer(id), String.to_integer(minutes)) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:show_station_modal, false)
         |> assign(:selected_station, nil)}

      {:error, :not_found} ->
        {:noreply, assign(socket, :registration_error, "Reservation not found")}
    end
  end

  defp do_cancel_station(%{"station_number" => id, "cancel_reason" => reason}, socket) do
    case ReservationLogic.cancel_reservation(String.to_integer(id), reason) do
      :ok ->
        {:noreply,
         socket
         |> assign(:show_station_modal, false)
         |> assign(:selected_station, nil)}

      {:error, :not_found} ->
        {:noreply, assign(socket, :registration_error, "No active reservation found")}
    end
  end

  defp do_close_station(%{"station_number" => station_number}, socket) do
    {:ok, _} =
      StationLogic.set_station_broken(
        String.to_integer(station_number),
        true
      )

    {:noreply,
     socket
     |> assign(:show_station_modal, false)
     |> assign(:selected_station, nil)}
  end

  defp do_open_station(%{"station_number" => station_number}, socket) do
    {:ok, _} =
      StationLogic.set_station_broken(
        String.to_integer(station_number),
        false
      )

    {:noreply,
     socket
     |> assign(:show_station_modal, false)
     |> assign(:selected_station, nil)}
  end

  # ============================================================================
  # PubSub Handlers
  # ============================================================================

  def handle_info({:stations, station_list}, socket) do
    # Reload settings in case padding/gaps changed
    {:ok, settings} = SettingsLogic.get_settings()

    # Update selected station data if modal is open
    selected_station =
      if socket.assigns.selected_station do
        station_number = socket.assigns.selected_station.station.station_number
        {new_stations, _} = StationLogic.stations_by_xy(station_list)
        find_station_data(new_stations, station_number)
      else
        nil
      end

    socket =
      socket
      |> assign(:colpad, settings.column_padding)
      |> assign(:rowpad, settings.row_padding)
      |> assign_stations(station_list)
      |> assign(:selected_station, selected_station)

    {:noreply, socket}
  end

  # ============================================================================
  # Render
  # ============================================================================

  def render(assigns) do
    ~H"""
    <div>
      <.page_header
        title="Stations"
        subtitle="Select an available station to reserve / Sélectionnez une station disponible pour réserver"
      />

      <.station_legend class="mb-6" />

      <.station_grid
        stations={@stations}
        rows={@rows}
        columns={@columns}
        rowpad={@rowpad}
        colpad={@colpad}
      >
        <:cell :let={station_data}>
          <StationModal.station_button
            station={station_data.station}
            status={station_data.status}
            reservation={station_data.reservation}
          />
        </:cell>
      </.station_grid>

      <%!-- Single shared station modal --%>
      <dialog
        id="station-modal"
        class={["modal", @show_station_modal && "modal-open"]}
        phx-window-keydown={@show_station_modal && "close_station_modal"}
        phx-key="Escape"
      >
        <%= if @selected_station do %>
          <.focus_wrap id="station-modal-focus" class="modal-box">
            <button
              type="button"
              class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
              phx-click="close_station_modal"
            >
              ✕
            </button>

            <StationModal.modal_content
              station={@selected_station.station}
              status={@selected_station.status}
              reservation={@selected_station.reservation}
              error={@registration_error}
              is_admin={@current_scope != nil && @current_scope.user != nil}
            />
          </.focus_wrap>
        <% end %>
        <div class="modal-backdrop" phx-click="close_station_modal"></div>
      </dialog>

      <%!-- Sudo verification modal --%>
      <dialog
        id="sudo-modal"
        class={["modal", @show_sudo_modal && "modal-open"]}
        phx-window-keydown={@show_sudo_modal && "close_sudo_modal"}
        phx-key="Escape"
      >
        <.focus_wrap :if={@show_sudo_modal} id="sudo-modal-focus" class="modal-box">
          <button
            type="button"
            class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
            phx-click="close_sudo_modal"
          >
            ✕
          </button>

          <h3 class="text-xl font-bold mb-4">
            Admin Verification / Vérification admin
          </h3>

          <p class="text-base-content/80 mb-2">
            Please scan your admin badge to confirm this action.
          </p>
          <p class="text-base-content/80 text-sm mb-4">
            Veuillez scanner votre badge admin pour confirmer cette action.
          </p>

          <div class="bg-base-200 p-3 rounded-lg mb-4 text-sm">
            <span class="font-semibold">Action:</span>
            {format_pending_action(@pending_action)}
          </div>

          <%= if @sudo_error do %>
            <div class="alert alert-error mb-4">
              <span>{@sudo_error}</span>
            </div>
          <% end %>

          <form phx-submit="verify_sudo">
            <div class="form-control">
              <label class="label">
                <span class="label-text">Admin badge / Badge admin</span>
              </label>
              <input
                type="text"
                placeholder="Scan or enter badge number..."
                class="input input-bordered w-full"
                name="badge_number"
                autocomplete="off"
                id="sudo-badge-input"
                phx-hook="AutoFocus"
              />
            </div>

            <div class="modal-action">
              <button type="button" class="btn btn-ghost" phx-click="close_sudo_modal">
                Cancel / Annuler
              </button>
              <button type="submit" class="btn btn-primary">
                Verify / Vérifier
              </button>
            </div>
          </form>
        </.focus_wrap>
        <div class="modal-backdrop" phx-click="close_sudo_modal"></div>
      </dialog>
    </div>
    """
  end
end
