defmodule LanpartyseatingWeb.Settings.ReservationsLive do
  @moduledoc """
  Settings page for reservation duration and tournament buffer configuration.
  """
  use LanpartyseatingWeb, :live_view
  require Logger

  alias Lanpartyseating.Repo
  alias Lanpartyseating.PubSub
  alias Lanpartyseating.SettingsLogic
  alias LanpartyseatingWeb.Components.SettingsNav

  # ============================================================================
  # Mount & Handle Params
  # ============================================================================

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, load_data(socket)}
  end

  defp load_data(socket) do
    {:ok, settings} = SettingsLogic.get_settings()

    socket
    |> assign(:reservation_duration, settings.reservation_duration_minutes)
    |> assign(:tournament_buffer, settings.tournament_buffer_minutes)
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  def handle_event("change_settings", params, socket) do
    reservation_duration =
      params
      |> Map.get("reservation_duration", to_string(socket.assigns.reservation_duration))
      |> String.to_integer()

    tournament_buffer =
      params
      |> Map.get("tournament_buffer", to_string(socket.assigns.tournament_buffer))
      |> String.to_integer()

    {:noreply,
     socket
     |> assign(:reservation_duration, reservation_duration)
     |> assign(:tournament_buffer, tournament_buffer)}
  end

  def handle_event("save", _params, socket) do
    s = socket.assigns

    save_settings =
      SettingsLogic.settings_db_changes(%{
        reservation_duration_minutes: s.reservation_duration,
        tournament_buffer_minutes: s.tournament_buffer,
      })

    socket =
      try do
        case Repo.transaction(save_settings) do
          {:ok, _result} ->
            publish_station_update()

            socket
            |> put_flash(:info, "Settings saved")

          {:error, failed_operation, failed_value, _changes_so_far} ->
            Logger.error("Transaction error: #{failed_operation} - #{inspect(failed_value)}")

            socket
            |> put_flash(:error, "Failed to save settings")
        end
      rescue
        e ->
          Logger.error("Exception saving settings: #{inspect(e)}")
          socket |> put_flash(:error, "Failed to save settings")
      end

    {:noreply, socket}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp publish_station_update do
    {:ok, settings} = SettingsLogic.get_settings()
    {:ok, stations} = Lanpartyseating.StationLogic.get_all_stations(DateTime.utc_now(), settings.tournament_buffer_minutes)
    Phoenix.PubSub.broadcast(PubSub, "station_update", {:stations, stations})
  end

  # ============================================================================
  # Render
  # ============================================================================

  def render(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open">
      <input id="settings-drawer" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content">
        <%!-- Mobile header with hamburger --%>
        <div class="lg:hidden navbar bg-base-200 border-b border-base-300">
          <label for="settings-drawer" class="btn btn-square btn-ghost">
            <Icons.menu />
          </label>
          <span class="text-lg font-bold">Reservations</span>
        </div>

        <%!-- Main content area --%>
        <div class="p-4 lg:p-6">
          <.reservations_content {assigns} />
        </div>
      </div>

      <div class="drawer-side z-40">
        <label for="settings-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <SettingsNav.settings_nav current_page={:reservations} is_user_auth={@is_user_auth} />
      </div>
    </div>
    """
  end

  defp reservations_content(assigns) do
    ~H"""
    <div class="max-w-2xl">
      <.page_header
        title="Reservation Settings"
        subtitle="Configure reservation duration and tournament buffer times"
      />

      <.admin_section title="Time Settings">
        <form id="reservation-settings-form" phx-change="change_settings" class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
            <div>
              <h3 class="font-medium mb-3">Reservation Duration</h3>
              <.labeled_input
                label="Minutes"
                type="number"
                name="reservation_duration"
                value={@reservation_duration}
                min={5}
                max={480}
              />
              <p class="text-xs text-base-content/50 mt-2">
                How long each reservation lasts (5-480 min)
              </p>
            </div>

            <div>
              <h3 class="font-medium mb-3">Tournament Buffer</h3>
              <.labeled_input
                label="Minutes"
                type="number"
                name="tournament_buffer"
                value={@tournament_buffer}
                min={5}
                max={480}
              />
              <p class="text-xs text-base-content/50 mt-2">
                How early to mark stations as reserved for tournaments (5-480 min)
              </p>
            </div>
          </div>

          <div class="flex justify-end pt-4 border-t border-base-300">
            <button type="button" class="btn btn-primary" phx-click="save">
              Save
            </button>
          </div>
        </form>
      </.admin_section>
    </div>
    """
  end
end
