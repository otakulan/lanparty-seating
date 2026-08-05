defmodule LanpartyseatingWeb.Settings.SeatMapsLive do
  @moduledoc """
  Catalogue of the Active Room's Seat Maps: list, rename, publish, duplicate, delete, and
  create new maps and rooms.
  """
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.PubSub
  alias Lanpartyseating.SeatMapsLogic
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
        {:noreply, put_flash(load(socket, String.to_integer(room_id)), :info, "Active room updated")}

      {:error, {:tournament_in_progress, name}} ->
        {:noreply,
         put_flash(socket, :error, "Cannot switch rooms while #{name} is underway")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  # --- Create ----------------------------------------------------------------

  def handle_event("create_map", _params, socket) do
    room_id = socket.assigns.selected_room_id

    case SeatMapsLogic.create_seat_map(%{room_id: room_id, name: "New Layout"}) do
      {:ok, _map} ->
        {:noreply, put_flash(load(socket, room_id), :info, "Map created")}

      {:error, changeset = %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("new_room", _params, socket) do
    case SeatMapsLogic.create_room(%{name: SeatMapsLogic.random_room_name()}) do
      {:ok, room} ->
        {:noreply, put_flash(load(socket, room.id), :info, "Room created")}

      {:error, changeset = %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
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
         |> put_flash(:info, "Map published")}

      {:error, {:active_reservations, _ids}} ->
        {:noreply,
         socket
         |> assign(:publish_target, nil)
         |> put_flash(:error, "Cannot publish: active seats changed")}

      {:error, {:tournament_in_progress, name}} ->
        {:noreply,
         socket
         |> assign(:publish_target, nil)
         |> put_flash(:error, "Cannot publish during #{name}")}

      {:error, reason} ->
        {:noreply, assign(socket, :publish_target, nil) |> put_flash(:error, inspect(reason))}
    end
  end

  # --- Duplicate / Delete ----------------------------------------------------

  def handle_event("duplicate_map", %{"map_id" => map_id, "version_id" => version_id}, socket) do
    case SeatMapsLogic.duplicate_seat_map(String.to_integer(map_id), String.to_integer(version_id)) do
      {:ok, _map} ->
        {:noreply, put_flash(load(socket, socket.assigns.selected_room_id), :info, "Map duplicated")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("delete_map", %{"map_id" => map_id}, socket) do
    case SeatMapsLogic.delete_seat_map(String.to_integer(map_id)) do
      {:ok, _map} ->
        {:noreply, put_flash(load(socket, socket.assigns.selected_room_id), :info, "Map deleted")}

      {:error, :published} ->
        {:noreply, put_flash(socket, :error, "Cannot delete the published map")}

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
          <.page_header title="Seat Maps">
            <:trailing>
              <div class="flex items-center gap-2">
                <button phx-click="new_room" class="btn btn-sm btn-ghost">
                  <Icons.plus class="w-4 h-4" /> New room
                </button>
                <button phx-click="create_map" class="btn btn-sm btn-primary">
                  <Icons.plus class="w-4 h-4" /> New map
                </button>
              </div>
            </:trailing>
          </.page_header>

          <.admin_section title={@room_name}>
            <:trailing>
              <div class="flex items-center gap-2">
                <.form for={%{}} phx-change="set_active_room">
                  <select disabled={@rooms == []} name="room_id" class="select select-bordered select-sm bg-base-100 text-base-content/70">
                    <%= if @rooms != [] do %>
                      <option :for={room <- @rooms} value={room.id} selected={room.id == @selected_room_id}><%= room.name %></option>
                    <% else %>
                      <option selected>No room</option>
                    <% end %>
                  </select>
                </.form>
              </div>
            </:trailing>
            <div class="overflow-x-auto border border-base-300 rounded-lg">
              <table class="table">
                <thead>
                  <tr class="border-b-2 border-base-300 bg-base-200">
                    <th>Name</th>
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
                          <span class="badge badge-success gap-1"><Icons.check class="w-3 h-3" /> Published</span>
                        <% else %>
                          <span class="badge badge-ghost">Draft</span>
                        <% end %>
                      </td>
                      <td class="text-right whitespace-nowrap">
                        <.link navigate={~p"/settings/seat-maps/#{map.public_id}/edit"} class="btn btn-xs btn-ghost">Edit</.link>
                        <button phx-click="open_publish" phx-value-map_id={map.id} class="btn btn-xs btn-primary">Publish</button>
                        <%
                           extra_attrs =  if map.published, do: [disabled: "true", title: "Cannot delete the published map"], else: []
                        %>
                        <button
                          class={"btn btn-xs btn-error " <> if(map.published, do: "btn-disabled", else: "")}
                          data-confirm={"Delete #{map.name}?"}
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
                This switches the Room to a different map. <%= @publish_target.reservation_count %> active reservation(s) will be cancelled and desktop clients disconnected.
              </p>
            <% else %>
              <p class="text-sm text-base-content/70 mb-4">
                This republishes the current map.
              </p>
            <% end %>
            <div class="modal-action">
              <button phx-click="cancel_publish" class="btn btn-ghost">Cancel</button>
              <button phx-click="confirm_publish" class="btn btn-primary">Publish</button>
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

    socket
    |> assign(:rooms, rooms)
    |> assign(:selected_room_id, selected_room_id)
    |> assign(:room_name, room_name)
    |> assign(:maps, maps)
    |> assign(:versions_by_map, versions_by_map)
    |> assign(:publish_target, socket.assigns[:publish_target])
  end

  defp active_room_id do
    case SeatMapsLogic.get_active_room() do
      {:ok, room} -> room.id
      _ -> nil
    end
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field} #{&1}") end)
    |> Enum.join(", ")
  end

  defp format_error(other), do: inspect(other)
end
