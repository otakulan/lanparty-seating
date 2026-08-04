defmodule LanpartyseatingWeb.Settings.SeatMapsLive do
  @moduledoc """
  Catalogue of the Active Room's Seat Maps: list, rename, publish, duplicate, delete, and
  create new maps and rooms.
  """
  use LanpartyseatingWeb, :live_view

  import Ecto.Query

  alias Lanpartyseating.PubSub
  alias Lanpartyseating.Repo
  alias Lanpartyseating.SeatMapsLogic
  alias LanpartyseatingWeb.Components.RoomOnboarding
  alias LanpartyseatingWeb.Components.SettingsNav

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "seat_map_update")
    end

    {:ok, load(socket, nil)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_info({:seat_map_updated, _payload}, socket) do
    {:noreply, load(socket, socket.assigns.selected_room_id)}
  end

  # --- Room scoping ----------------------------------------------------------

  def handle_event("set_active_room", %{"room_id" => room_id}, socket) do
    case SeatMapsLogic.set_active_room(String.to_integer(room_id)) do
      {:ok, :already_active} ->
        {:noreply, load(socket, String.to_integer(room_id))}

      {:ok, _room} ->
        {:noreply, put_flash(load(socket, String.to_integer(room_id)), :info, "Active room updated / Salle active mise à jour")}

      {:error, {:tournament_in_progress, name}} ->
        {:noreply,
         put_flash(socket, :error, "Cannot switch rooms while #{name} is underway / Impossible de changer de salle pendant le tournoi")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  # --- Create ----------------------------------------------------------------

  def handle_event("create_map", _params, socket) do
    room_id = socket.assigns.selected_room_id

    case SeatMapsLogic.create_seat_map(%{room_id: room_id, name: "New Layout / Nouvelle disposition"}) do
      {:ok, _map} ->
        {:noreply, put_flash(load(socket, room_id), :info, "Map created / Carte créée")}

      {:error, changeset = %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("create_room", %{"room" => room_params}, socket) do
    case SeatMapsLogic.create_room(room_params) do
      {:ok, _room} ->
        {:noreply, put_flash(load(socket, nil), :info, "Room created / Salle créée")}

      {:error, changeset = %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("toggle_new_room", _params, socket) do
    {:noreply, assign(socket, :show_new_room, not socket.assigns.show_new_room)}
  end

  # --- Rename ----------------------------------------------------------------

  def handle_event("rename_map", %{"map_id" => map_id, "name" => name}, socket) do
    case SeatMapsLogic.rename_seat_map(String.to_integer(map_id), String.trim(name)) do
      {:ok, _map} ->
        {:noreply, load(socket, socket.assigns.selected_room_id)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}
    end
  end

  # --- Publish ---------------------------------------------------------------

  def handle_event("open_publish", %{"map_id" => map_id}, socket) do
    room_id = socket.assigns.selected_room_id
    maps = SeatMapsLogic.list_seat_maps(room_id)
    target = Enum.find(maps, &(&1.id == String.to_integer(map_id)))

    is_cross =
      case SeatMapsLogic.get_active_room() do
        {:ok, room} ->
          room.published_version && room.published_version.seat_map_id != target.id

        _ ->
          true
      end

    count = if is_cross, do: SeatMapsLogic.active_reservation_count(), else: 0

    {:noreply, assign(socket, :publish_target, %{map_id: target.id, name: target.name, cross: is_cross, reservation_count: count})}
  end

  def handle_event("cancel_publish", _params, socket) do
    {:noreply, assign(socket, :publish_target, nil)}
  end

  def handle_event("confirm_publish", _params, socket) do
    %{map_id: map_id} = socket.assigns.publish_target

    case SeatMapsLogic.publish_seat_map(map_id) do
      {:ok, _version} ->
        {:noreply,
         socket
         |> assign(:publish_target, nil)
         |> load(socket.assigns.selected_room_id)
         |> put_flash(:info, "Map published / Carte publiée")}

      {:error, {:active_reservations, _ids}} ->
        {:noreply,
         socket
         |> assign(:publish_target, nil)
         |> put_flash(:error, "Cannot publish: active seats changed / Publication impossible")}

      {:error, {:tournament_in_progress, name}} ->
        {:noreply,
         socket
         |> assign(:publish_target, nil)
         |> put_flash(:error, "Cannot publish during #{name} / Publication impossible pendant le tournoi")}

      {:error, reason} ->
        {:noreply, assign(socket, :publish_target, nil) |> put_flash(:error, inspect(reason))}
    end
  end

  # --- Duplicate / Delete ----------------------------------------------------

  def handle_event("duplicate_map", %{"map_id" => map_id, "version_id" => version_id}, socket) do
    case SeatMapsLogic.duplicate_seat_map(String.to_integer(map_id), String.to_integer(version_id)) do
      {:ok, _map} ->
        {:noreply, put_flash(load(socket, socket.assigns.selected_room_id), :info, "Map duplicated / Carte dupliquée")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("delete_map", %{"map_id" => map_id}, socket) do
    case SeatMapsLogic.delete_seat_map(String.to_integer(map_id)) do
      {:ok, _map} ->
        {:noreply, put_flash(load(socket, socket.assigns.selected_room_id), :info, "Map deleted / Carte supprimée")}

      {:error, :published} ->
        {:noreply, put_flash(socket, :error, "Cannot delete the published map / Impossible de supprimer la carte publiée")}

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
          <span class="text-lg font-bold font-mono text-base-content">Seat Maps</span>
        </div>

        <div class="flex min-h-0 flex-1 flex-col gap-4 p-4 lg:p-6">
          <.page_header title="Seat Maps / Cartes">
            <:trailing>
              <div class="flex items-center gap-2">
                <.form for={%{}} phx-change="set_active_room">
                  <select :if={@rooms != []} name="room_id" class="select select-bordered select-sm bg-base-100 text-base-content/70">
                    <option :for={room <- @rooms} value={room.id} selected={room.id == @selected_room_id}><%= room.name %></option>
                  </select>
                </.form>
                <button phx-click="toggle_new_room" class="btn btn-sm btn-ghost">
                  <Icons.plus class="w-4 h-4" /> New room / Nouvelle salle
                </button>
                <button phx-click="create_map" class="btn btn-sm btn-primary">
                  <Icons.plus class="w-4 h-4" /> New map / Nouvelle carte
                </button>
              </div>
            </:trailing>
          </.page_header>

          <%= if @show_new_room do %>
            <.admin_section title="New room / Nouvelle salle">
              <RoomOnboarding.room_onboarding
                room={@onboarding_room}
                seat_count={@seat_count}
                first_map={@first_map}
                has_published={@has_published}
              />
            </.admin_section>
          <% end %>

          <.admin_section title={"Seat Maps / Cartes — " <> @room_name}>
            <div class="overflow-x-auto border border-base-300 rounded-lg">
              <table class="table">
                <thead>
                  <tr class="border-b-2 border-base-300 bg-base-200">
                    <th>Name / Nom</th>
                    <th>ID</th>
                    <th>Version</th>
                    <th>Status</th>
                    <th class="text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for map <- @maps do %>
                    <tr>
                      <td>
                        <form id={"rename-map-#{map.id}"} phx-submit="rename_map" class="flex gap-1 items-center">
                          <input type="hidden" name="map_id" value={map.id} />
                          <input
                            type="text"
                            name="name"
                            value={map.name}
                            class="input input-xs input-bordered w-48"
                            phx-blur="rename_map"
                          />
                        </form>
                      </td>
                      <td class="font-mono text-base-content/50 text-xs"><%= map.public_id %></td>
                      <td>
                        <.form id={"duplicate-map-#{map.id}"} for={%{}} phx-submit="duplicate_map" class="flex gap-1 items-center">
                          <input type="hidden" name="map_id" value={map.id} />
                          <select name="version_id" class="select select-xs select-bordered bg-base-100">
                            <%= for version <- @versions_by_map[map.id] || [] do %>
                              <option value={version.id}>Rev <%= version.revision %></option>
                            <% end %>
                          </select>
                          <button type="submit" class="btn btn-xs btn-ghost">Duplicate</button>
                        </.form>
                      </td>
                      <td>
                        <%= if map.published do %>
                          <span class="badge badge-success gap-1"><Icons.check class="w-3 h-3" /> Published / Publiée</span>
                        <% else %>
                          <span class="badge badge-ghost">Draft / Brouillon</span>
                        <% end %>
                      </td>
                      <td class="text-right whitespace-nowrap">
                        <.link navigate={~p"/settings/seat-maps/#{map.public_id}/edit"} class="btn btn-xs btn-ghost">Edit</.link>
                        <button phx-click="open_publish" phx-value-map_id={map.id} class="btn btn-xs btn-primary">Publish</button>
                        <%
                           extra_attrs =  if map.published, do: [disabled: "true", title: "Cannot delete the published map / Impossible de supprimer la carte publiée"], else: []
                        %>
                        <button
                          class={"btn btn-xs btn-error " <> if(map.published, do: "btn-disabled", else: "")}
                          data-confirm={"Delete #{map.name}? / Supprimer #{map.name} ?"}
                          phx-click={if(map.published, do: "", else: "delete_map")}
                          phx-value-map_id={map.id}
                          {extra_attrs}
                        >
                          Delete
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </.admin_section>
        </div>
      </div>

      <div class="drawer-side z-40">
        <label for="settings-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <SettingsNav.settings_nav current_page={:seat_maps} is_user_auth={@is_user_auth} />
      </div>

      <div class={"modal " <> if(@publish_target, do: "modal-open", else: "")}>
        <div class="modal-box">
          <form method="dialog">
            <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
          </form>
          <%= if @publish_target do %>
            <h3 class="text-lg font-bold mb-2">Publish "<%= @publish_target.name %>"?</h3>
            <%= if @publish_target.cross do %>
              <p class="text-sm text-base-content/70 mb-4">
                This switches the Room to a different map. <%= @publish_target.reservation_count %> active reservation(s) will be cancelled and desktop clients disconnected. / Cette action annule les réservations actives et déconnecte les clients.
              </p>
            <% else %>
              <p class="text-sm text-base-content/70 mb-4">
                This republishes the current map. / Cette action republie la carte actuelle.
              </p>
            <% end %>
            <div class="modal-action">
              <button phx-click="cancel_publish" class="btn btn-ghost">Cancel / Annuler</button>
              <button phx-click="confirm_publish" class="btn btn-primary">Publish / Publier</button>
            </div>
          <% end %>
        </div>
        <form method="dialog" class="modal-backdrop"><button>close</button></form>
      </div>
    </div>
    """
  end

  defp load(socket, selected_room_id) do
    rooms = SeatMapsLogic.list_rooms()

    selected_room_id =
      case selected_room_id do
        id when is_integer(id) -> id
        _ -> active_room_id()
      end

    maps = if is_nil(selected_room_id),
            do: [],
            else: SeatMapsLogic.list_seat_maps(selected_room_id)
    room_name = Enum.find_value(rooms, "—", &if(&1.id == selected_room_id, do: &1.name))

    versions_by_map = maps |> Enum.into(%{}, fn (map) -> {map.id, SeatMapsLogic.list_versions(map.id)} end)

    onboarding = onboarding_state(selected_room_id)

    socket
    |> assign(:rooms, rooms)
    |> assign(:selected_room_id, selected_room_id)
    |> assign(:room_name, room_name)
    |> assign(:maps, maps)
    |> assign(:versions_by_map, versions_by_map)
    |> assign(:publish_target, socket.assigns[:publish_target])
    |> assign(:show_new_room, socket.assigns[:show_new_room] || false)
    |> assign(:onboarding_room, onboarding.room)
    |> assign(:seat_count, onboarding.seat_count)
    |> assign(:first_map, onboarding.first_map)
    |> assign(:has_published, onboarding.has_published)
  end

  defp active_room_id do
    case SeatMapsLogic.get_active_room() do
      {:ok, room} -> room.id
      _ -> nil
    end
  end

  defp onboarding_state(nil) do
    %{room: nil, seat_count: 0, first_map: nil, has_published: false}
  end

  defp onboarding_state(active_room_id) do
    room = Lanpartyseating.Room |> Repo.get(active_room_id, [preload: [:published_version]])

    seat_count =
      Lanpartyseating.SeatSlot
      |> where([s], s.room_id == ^active_room_id and is_nil(s.deleted_at))
      |> Repo.aggregate(:count, :id)

    maps = SeatMapsLogic.list_seat_maps(active_room_id)
    first_map = List.first(maps)

    %{
      room: room,
      seat_count: seat_count,
      first_map: first_map && %{id: first_map.id, public_id: first_map.public_id},
      has_published: not is_nil(room.published_version_id)
    }
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field} #{&1}") end)
    |> Enum.join(", ")
  end

  defp format_error(other), do: inspect(other)
end
