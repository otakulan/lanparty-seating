defmodule LanpartyseatingWeb.Settings.GeneralLive do
  @moduledoc """
  General settings landing page. Hosts the Active Room selector and the kiosk seat-picking
  toggle.
  """
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.RoomsLogic
  alias Lanpartyseating.SettingsLogic
  alias LanpartyseatingWeb.Components.SettingsNav

  def mount(_params, _session, socket) do
    {:ok, load(socket)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, load(socket)}
  end

  def handle_event("set_active_room", %{"room_id" => room_id}, socket) do
    case RoomsLogic.set_active_room(String.to_integer(room_id)) do
      {:ok, _room} ->
        {:noreply, put_flash(load(socket), :info, "Active room updated")}

      {:error, {:tournament_in_progress, name}} ->
        {:noreply, put_flash(socket, :error, "Cannot switch rooms while #{name} is underway")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("update_settings", params, socket) do
    seat_picking = Map.get(params, "seat_picking_enabled_in_kiosk", "false") == "true"

    SettingsLogic.settings_db_changes(%{seat_picking_enabled_in_kiosk: seat_picking})
    |> Lanpartyseating.Repo.transaction()

    {:noreply, load(socket)}
  end

  def render(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open h-fill grid-rows-1 overflow-hidden">
      <input id="settings-drawer" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content flex flex-col min-h-0 overflow-y-auto">
        <div class="lg:hidden navbar shrink-0 border-b border-base-300 bg-base-200">
          <label for="settings-drawer" class="btn btn-square btn-ghost text-base-content/60">
            <Icons.menu />
          </label>
          <span class="text-lg font-bold font-mono text-base-content">General</span>
        </div>

        <div class="flex min-h-0 flex-1 flex-col gap-6 p-4 lg:p-6">
          <.page_header title="General" subtitle="Global event settings" />

          <.admin_section title="Active Room">
            <p class="text-sm text-base-content/60 mb-3">
              The Active Room is the one the whole application currently serves.
            </p>
            <.form for={%{}} phx-change="set_active_room" class="max-w-sm">
              <select name="room_id" disabled={@rooms == []} class="select select-bordered select-sm w-full bg-base-100 text-base-content/70">
                <%= if @rooms == [] do %>
                  <option selected>No rooms</option>
                <% else %>
                  <option :for={room <- @rooms} value={room.id} selected={room.id == @active_room_id}>
                    <%= room.name %>
                  </option>
                <% end %>
              </select>
            </.form>
          </.admin_section>

          <.admin_section title="Kiosk">
            <.form for={%{}} phx-change="update_settings">
              <label class="label cursor-pointer justify-start gap-3">
                <input
                  type="checkbox"
                  name="seat_picking_enabled_in_kiosk"
                  class="toggle toggle-primary"
                  value="true"
                  checked={@seat_picking_enabled_in_kiosk}
                />
                <span class="label-text text-base-content">
                  Seat picking enabled in kiosk
                </span>
              </label>
            </.form>
          </.admin_section>
        </div>
      </div>

      <div class="drawer-side z-40">
        <label for="settings-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <SettingsNav.settings_nav current_page={:general} is_user_auth={@is_user_auth} />
      </div>
    </div>
    """
  end

  defp load(socket) do
    settings = SettingsLogic.get_settings()
    rooms = RoomsLogic.list_rooms()

    socket
    |> assign(:rooms, rooms)
    |> assign(:active_room_id, settings.active_room_id)
    |> assign(:seat_picking_enabled_in_kiosk, settings.seat_picking_enabled_in_kiosk)
  end
end
