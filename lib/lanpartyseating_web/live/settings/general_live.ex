defmodule LanpartyseatingWeb.Settings.GeneralLive do
  @moduledoc """
  General settings landing page. Hosts the Active Room selector and the kiosk seat-picking
  toggle, and renders the onboarding checklist when setup is incomplete.
  """
  use LanpartyseatingWeb, :live_view

  import Ecto.Query

  alias Lanpartyseating.Room
  alias Lanpartyseating.SeatMapsLogic
  alias Lanpartyseating.SettingsLogic
  alias LanpartyseatingWeb.Components.RoomOnboarding
  alias LanpartyseatingWeb.Components.SettingsNav

  def mount(_params, _session, socket) do
    {:ok, load(socket)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, load(socket)}
  end

  def handle_event("set_active_room", %{"room_id" => room_id}, socket) do
    case SeatMapsLogic.set_active_room(String.to_integer(room_id)) do
      {:ok, _room} ->
        {:noreply, put_flash(load(socket), :info, "Active room updated / Salle active mise à jour")}

      {:error, {:tournament_in_progress, name}} ->
        {:noreply,
         put_flash(socket, :error, "Cannot switch rooms while #{name} is underway / Impossible de changer de salle pendant le tournoi")}

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

  def handle_event("create_room", %{"room" => room_params}, socket) do
    case SeatMapsLogic.create_room(room_params) do
      {:ok, _room} ->
        {:noreply, put_flash(load(socket), :info, "Room created / Salle créée")}

      {:error, changeset = %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("publish_first_map", %{"map_id" => map_id}, socket) do
    case SeatMapsLogic.publish_seat_map(String.to_integer(map_id)) do
      {:ok, _version} ->
        {:noreply, put_flash(load(socket), :info, "Map published / Carte publiée")}

      {:error, {:active_reservations, _ids}} ->
        {:noreply, put_flash(socket, :error, "Cannot publish: active seats changed / Publication impossible")}

      {:error, {:tournament_in_progress, name}} ->
        {:noreply,
         put_flash(socket, :error, "Cannot publish during #{name} / Publication impossible pendant le tournoi")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
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
          <.page_header title="General" subtitle="Global event settings / Paramètres globaux de l'événement" />

          <.admin_section title="Active Room / Salle active">
            <p class="text-sm text-base-content/60 mb-3">
              The Active Room is the one the whole application currently serves. / La salle active est celle que toute l'application sert.
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

          <.admin_section title="Kiosk / Borne">
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
                  Seat picking enabled in kiosk / Sélection de place activée à la borne
                </span>
              </label>
            </.form>
          </.admin_section>

          <%= if not @onboarding_complete do %>
            <RoomOnboarding.room_onboarding
              room={@onboarding_room}
              seat_count={@seat_count}
              first_map={@first_map}
              has_published={@has_published}
            />
          <% end %>
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
    rooms = SeatMapsLogic.list_rooms()
    onboarding = onboarding_state(settings.active_room_id)

    socket
    |> assign(:rooms, rooms)
    |> assign(:active_room_id, settings.active_room_id)
    |> assign(:seat_picking_enabled_in_kiosk, settings.seat_picking_enabled_in_kiosk)
    |> assign(:onboarding_room, onboarding.room)
    |> assign(:seat_count, onboarding.seat_count)
    |> assign(:first_map, onboarding.first_map)
    |> assign(:has_published, onboarding.has_published)
    |> assign(:onboarding_complete, onboarding.complete)
  end

  defp onboarding_state(nil) do
    %{room: nil, seat_count: 0, first_map: nil, has_published: false, complete: false}
  end

  defp onboarding_state(active_room_id) do
    {:ok, room} = {:ok, Lanpartyseating.Repo.get(Room, active_room_id) |> Lanpartyseating.Repo.preload(:published_version)}

    seat_count =
      Lanpartyseating.SeatSlot
      |> where([s], s.room_id == ^active_room_id and is_nil(s.deleted_at))
      |> Lanpartyseating.Repo.aggregate(:count, :id)

    maps = SeatMapsLogic.list_seat_maps(active_room_id)
    first_map = List.first(maps)
    has_published = not is_nil(room.published_version_id)

    %{
      room: room,
      seat_count: seat_count,
      first_map: first_map && %{id: first_map.id, public_id: first_map.public_id},
      has_published: has_published,
      complete: not is_nil(room) and seat_count > 0 and has_published
    }
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field} #{&1}") end)
    |> Enum.join(", ")
  end

  defp format_error(other), do: inspect(other)
end
