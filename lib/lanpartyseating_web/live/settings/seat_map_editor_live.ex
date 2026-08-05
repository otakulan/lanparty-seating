defmodule LanpartyseatingWeb.Settings.SeatMapEditorLive do
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.PubSub
  alias Lanpartyseating.SeatMapLayout
  alias Lanpartyseating.SeatMapsLogic
  alias LanpartyseatingWeb.Components.SeatMap
  alias LanpartyseatingWeb.Components.SettingsNav

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "seat_map_update")
    end

    socket =
      socket
      |> assign(:page_title, "Seat Map Editor")
      |> assign(:stale_version, false)
      |> assign(:ignore_stale_until_next_render, false)
      |> assign(:selected_seat, nil)

    {:ok, socket}
  end

  def handle_params(%{"public_id" => public_id}, _uri, socket) do
    {:noreply, load_editor(socket, public_id)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, push_navigate(socket, to: ~p"/settings/seat-maps")}
  end

  def handle_event("seat_selected", %{"seat" => nil}, socket) do
    {:noreply, assign(socket, :selected_seat, nil)}
  end

  def handle_event("seat_selected", %{"seat" => seat}, socket) do
    {:noreply, assign(socket, :selected_seat, seat)}
  end

  def handle_event("update_seat_label", %{"value" => label}, socket) do
    case update_selected_seat(socket, %{label: label}) do
      {:ok, socket} -> {:noreply, socket}
      {:error, socket} -> {:noreply, socket}
    end
  end

  def handle_event("update_seat_label", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("clear_seat_selection", _params, socket) do
    {:noreply, assign(socket, :selected_seat, nil)}
  end

  def handle_event("save_version", %{"map" => %{"revision" => revision} = map}, socket) do
    case SeatMapsLogic.save_version(socket.assigns.seat_map_id, map, revision) do
      {:ok, _version} ->
        payload = load_editor_payload(socket.assigns.public_id)

        {:noreply,
         socket
         |> assign_editor_payload(payload)
         |> assign(:stale_version, false)
         |> assign(:ignore_stale_until_next_render, true)
         |> push_event("seat_map_update", %{map: payload})
         |> put_flash(:info, "Version saved")}

      {:error, {:stale, _latest}} ->
        {:noreply,
         socket
         |> assign(:stale_version, true)
         |> clear_flash()
         |> put_flash(:error, "This map changed elsewhere. Reload before saving.")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}
    end
  end

  def handle_event("rename_map", %{"name" => name}, socket) do
    name = String.trim(name)

    case SeatMapsLogic.rename_seat_map(socket.assigns.seat_map_id, name) do
      {:ok, _map} ->
        {:noreply, assign(socket, :map_name, name) |> put_flash(:info, "Name updated")}

      {:error, changeset} ->
        refreshed = load_editor_payload(socket.assigns.public_id)
        {:noreply, assign(socket, :map_name, refreshed.name) |> put_flash(:error, format_error(changeset))}
    end
  end

  def handle_event("copy_export_json", _params, socket) do
    {:noreply, push_event(socket, "copy_to_clipboard", %{text: socket.assigns.export_json})}
  end

  def handle_event("import_json", %{"import" => %{"json" => json}}, socket) do
    with {:ok, decoded} <- SeatMapLayout.from_json(json),
         merged <- Map.put(decoded, :revision, socket.assigns.revision),
         {:ok, _version} <- SeatMapsLogic.save_version(socket.assigns.seat_map_id, merged, socket.assigns.revision) do
      payload = load_editor_payload(socket.assigns.public_id)

      {:noreply,
       socket
       |> assign_editor_payload(payload)
       |> push_event("seat_map_update", %{map: payload})
       |> put_flash(:info, "JSON imported")}
    else
      {:error, :invalid_json} ->
        {:noreply, put_flash(socket, :error, "Invalid JSON")}

      {:error, :invalid_layout} ->
        {:noreply, put_flash(socket, :error, "Invalid layout JSON")}

      {:error, {:stale, _latest}} ->
        {:noreply, put_flash(socket, :error, "This map changed elsewhere")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}
    end
  end

  def handle_event("save_background", %{"background" => params}, socket) do
    payload =
      socket.assigns.map_payload
      |> Map.put(:background_kind, params["kind"])
      |> Map.put(:background_value, normalize_background_value(params["kind"], params["value"]))
      |> Map.put(:revision, socket.assigns.revision)

    case SeatMapsLogic.save_version(socket.assigns.seat_map_id, payload, socket.assigns.revision) do
      {:ok, _version} ->
        refreshed = load_editor_payload(socket.assigns.public_id)

        {:noreply,
         socket
         |> assign_editor_payload(refreshed)
         |> push_event("seat_map_update", %{map: refreshed})
         |> put_flash(:info, "Background updated")}

      {:error, {:stale, _latest}} ->
        {:noreply, put_flash(socket, :error, "This map changed elsewhere")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_info({:seat_map_updated, _payload}, socket) do
    payload = load_editor_payload(socket.assigns.public_id)

    stale_version =
      payload.revision != socket.assigns.revision and
        not socket.assigns[:ignore_stale_until_next_render]

    socket =
      socket
      |> assign(:stale_version, stale_version)
      |> assign(:ignore_stale_until_next_render, false)

    socket =
      if stale_version do
        put_flash(socket, :error, "A newer version is available. Reload before continuing.")
      else
        socket
      end

    {:noreply, socket}
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
          <span class="text-lg font-bold font-mono text-base-content">Seat Map Editor</span>
        </div>

        <div class="flex min-h-0 flex-1 flex-col gap-4 p-4 lg:p-6">
          <%!-- Header --%>
          <div class="mb-4 flex items-center justify-between shrink-0">
            <div>
              <div class="flex items-center gap-2">
                <.link navigate={~p"/settings/seat-maps"} class="text-base-content/60 hover:text-base-content" title="Back to catalogue">
                  <Icons.chevron_left class="w-4 h-4" />
                </.link>
                <h1 class="text-xl font-bold text-base-content">Seat Map Editor</h1>
              </div>
              <p class="text-sm text-base-content/60">
                Shift-click to multi-select
              </p>
            </div>
            <div class="flex items-center gap-4">
              <div class="form-control">
                <input
                  type="text"
                  name="name"
                  value={@map_name}
                  placeholder="Map name"
                  phx-blur="rename_map"
                  class="input input-bordered input-sm w-64 bg-base-100 text-base-content"
                />
              </div>
              <div class="flex items-center gap-2">
                <span class="text-tiny uppercase tracking-[0.15em] text-base-content/60">Rev</span>
                <span class="font-mono text-success">{@revision}</span>
              </div>
              <%= if @stale_version do %>
                <div class="rounded border border-warning/50 bg-warning/10 px-3 py-1 text-sm text-warning">
                  Stale
                </div>
              <% end %>
            </div>
          </div>

          <SeatMap.canvas id="editor-seat-map" hook="SeatMapEditor" payload={@map_payload} mode="editor" class="flex-1 min-h-100" stage_class="h-full">
            <:toolbar with_zoom_buttons>
              <div class="flex flex-wrap gap-1">
                <button type="button" data-seat-map-command="add-seat" class="btn btn-xs btn-success gap-1">
                  <Icons.plus class="w-3 h-3" /> Seat
                </button>
                <button type="button" data-seat-map-command="add-table" class="btn btn-xs btn-info gap-1">
                  <Icons.plus class="w-3 h-3" /> Table
                </button>
                <button type="button" data-seat-map-command="add-label" class="btn btn-xs btn-warning gap-1">
                  <Icons.plus class="w-3 h-3" /> Label
                </button>
              </div>
              <div class="mini-separator"></div>
              <div class="flex flex-wrap gap-1">
                <button type="button" data-seat-map-command="delete-selection" class="btn btn-xs btn-error" title="Delete selection">
                  <Icons.trash class="w-4 h-4" />
                </button>
              </div>
              <div class="mini-separator"></div>
              <div class="flex flex-wrap gap-1">
                <button type="button" data-seat-map-command="undo" class="btn btn-xs" title="Undo (Ctrl+Z)">
                  <Icons.undo class="w-4 h-4"/>
                </button>
                <button type="button" data-seat-map-command="redo" class="btn btn-xs" title="Redo (Ctrl+Shift+Z)">
                  <Icons.redo class="w-4 h-4"/>
                </button>
              </div>
              <div class="mini-separator"></div>
              <div class="flex flex-wrap gap-1">
                <button type="button" data-seat-map-command="save" class="btn btn-xs btn-success">
                  <Icons.save class="w-4 h-4" /> Save
                </button>
              </div>
            </:toolbar>

            <:details :if={@selected_seat}>
              <div class="space-y-2">
                <div class="flex items-center justify-between">
                  <span class="text-tiny uppercase tracking-[0.15em] text-base-content/60">Selected</span>
                  <button type="button" phx-click="clear_seat_selection" class="btn btn-xs btn-ghost btn-circle">
                    <Icons.x class="w-4 h-4" />
                  </button>
                </div>
                <h3 class="text-lg font-bold text-base-content">{@selected_seat["label"]}</h3>
                <div class="form-control">
                  <label class="label py-1">
                    <span class="label-text text-tiny uppercase text-base-content/60">Label</span>
                  </label>
                  <input
                    type="text"
                    name="label"
                    value={@selected_seat["label"]}
                    class="input input-bordered input-sm w-full bg-base-100 text-base-content"
                    placeholder="Seat label"
                    phx-blur="update_seat_label"
                  />
                </div>
                <div class="grid grid-cols-2 gap-2 text-tiny">
                  <div>
                    <span class="text-base-content/60">Status</span>
                    <span class="ml-1 font-mono text-success">{@selected_seat["status"]}</span>
                  </div>
                  <div>
                    <span class="text-base-content/60">ID</span>
                    <span class="ml-1 font-mono text-base-content">{@selected_seat["seat_slot_id"]}</span>
                  </div>
                </div>
              </div>
            </:details>
          </SeatMap.canvas>

          <%!-- Bottom panels --%>
          <div class="grid gap-4 shrink-0 md:grid-cols-2">
            <div class="rounded-lg border border-base-300 bg-base-200 p-4">
              <h3 class="text-sm font-semibold text-base-content mb-3 flex items-center gap-2">
                <Icons.upload class="w-4 h-4" /> Background
              </h3>
              <.form for={%{}} as={:background} phx-submit="save_background" class="space-y-2">
                <select name="background[kind]" class="select select-bordered select-sm w-full bg-base-100 text-base-content/70">
                  <option value="none" selected={@background_kind == "none"}>None</option>
                  <option value="svg" selected={@background_kind == "svg"}>SVG</option>
                  <option value="image" selected={@background_kind == "image"}>Image URL</option>
                </select>
                <input
                  name="background[value]"
                  value={@background_value}
                  class="input input-bordered input-sm w-full bg-base-100 text-base-content/70"
                  placeholder="SVG or image URL"
                />
                <button type="submit" class="btn btn-sm w-full btn-ghost text-warning hover:bg-warning/10">Set</button>
              </.form>
            </div>

            <div class="rounded-lg border border-base-300 bg-base-200 p-4">
              <h3 class="text-sm font-semibold text-base-content mb-3 flex items-center gap-2">
                <Icons.refresh_cw class="w-4 h-4" /> Import / Export
              </h3>
              <div class="space-y-2">
                <button
                  type="button"
                  phx-click="copy_export_json"
                  class="btn btn-sm w-full btn-ghost text-base-content/70 hover:bg-base-content/10"
                >
                  Copy JSON to clipboard
                </button>
                <.form for={%{}} as={:import} phx-submit="import_json">
                  <input
                    type="hidden"
                    name="import[json]"
                    value={@import_json}
                  />
                  <button type="submit" class="btn btn-sm w-full btn-ghost text-info hover:bg-info/10">
                    Reset from JSON
                  </button>
                </.form>
              </div>
              <div class="mt-3">
                <details class="group">
                  <summary class="cursor-pointer text-xs text-base-content/50 hover:text-base-content/70">
                    Show raw JSON
                  </summary>
                  <textarea
                    data-seat-map-export-for="editor-seat-map"
                    class="textarea textarea-bordered mt-2 h-32 w-full bg-base-100 font-mono text-xs text-base-content/70"
                    readonly
                  >{@export_json}</textarea>
                </details>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="drawer-side z-40">
        <label for="settings-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <SettingsNav.settings_nav current_page={:seat_maps} is_user_auth={@is_user_auth} />
      </div>
    </div>
    """
  end

  defp load_editor(socket, public_id) do
    case load_editor_payload(public_id) do
      {:ok, payload} ->
        socket
        |> assign(:public_id, public_id)
        |> assign_editor_payload(payload)
        |> push_event("seat_map_init", %{map: payload})

      {:error, :not_found} ->
        push_navigate(socket, to: ~p"/settings/seat-maps")

      {:error, _} ->
        push_navigate(socket, to: ~p"/settings/seat-maps")
    end
  end

  defp load_editor_payload(public_id) do
    SeatMapsLogic.get_editor_payload(public_id)
  end

  defp assign_editor_payload(socket, payload) do
    json_payload = Jason.encode!(payload, pretty: true)

    socket
    |> assign(:seat_map_id, payload.seat_map_id)
    |> assign(:map_payload, payload)
    |> assign(:map_name, payload.name || "Untitled")
    |> assign(:revision, payload.revision || 1)
    |> assign(:background_kind, payload.background_kind || "none")
    |> assign(:background_value, background_editor_value(payload))
    |> assign(:export_json, json_payload)
    |> assign(:import_json, json_payload)
  end

  defp background_editor_value(%{background_kind: "svg", background_value: value}) when is_binary(value) do
    if String.starts_with?(value, "data:image/svg+xml,") do
      value
      |> String.replace_prefix("data:image/svg+xml,", "")
      |> URI.decode()
    else
      value
    end
  end

  defp background_editor_value(_payload), do: nil

  defp update_selected_seat(socket, updates) do
    case socket.assigns.selected_seat do
      nil ->
        {:error, socket}

      selected_seat ->
        seat_slot_id = selected_seat["seat_slot_id"]

        updated_seats =
          (socket.assigns.map_payload.seats || [])
          |> Enum.map(
            fn seat ->
              if seat.seat_slot_id == seat_slot_id, do: Map.merge(seat, updates), else: seat
            end
          )

        updated_payload = Map.put(socket.assigns.map_payload, :seats, updated_seats)

        string_updates = Map.new(updates, fn {k, v} -> {to_string(k), v} end)

        {:ok,
         socket
         |> assign(:map_payload, updated_payload)
         |> assign(:selected_seat, Map.merge(selected_seat, string_updates))
         |> push_event("seat_map_update", %{map: updated_payload})}
    end
  end

  defp normalize_background_value("svg", value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" -> nil
      String.starts_with?(trimmed, "data:image/svg+xml,") -> trimmed
      String.starts_with?(trimmed, "<svg") -> "data:image/svg+xml," <> URI.encode(trimmed)
      true -> trimmed
    end
  end

  defp normalize_background_value(_kind, value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_background_value(_kind, _value), do: nil

  defp format_error(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field} #{&1}") end)
    |> Enum.join(", ")
  end

  defp format_error(other), do: inspect(other)
end
