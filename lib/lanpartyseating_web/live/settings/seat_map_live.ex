defmodule LanpartyseatingWeb.Settings.SeatMapLive do
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.PubSub
  alias Lanpartyseating.SeatMapsLogic
  alias Lanpartyseating.TournamentsLogic
  alias LanpartyseatingWeb.Components.SeatMap
  alias LanpartyseatingWeb.Components.SettingsNav

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "seat_map_update")
    end

    payload = load_editor_payload()

    socket =
      socket
      |> assign(:page_title, "Seat Map Editor")
      |> assign_editor_payload(payload)
      |> assign(:stale_draft, false)
      |> assign(:ignore_stale_until_next_render, false)
      |> assign(:selected_seat, nil)

    socket = if connected?(socket), do: push_event(socket, "seat_map_init", %{map: payload}), else: socket
    {:ok, socket}
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

  def handle_event("save_draft_preview", %{"map" => %{"revision" => revision} = map}, socket) do
    case SeatMapsLogic.save_draft(map, revision) do
      {:ok, _version} ->
        payload = load_editor_payload()

        {:noreply,
         socket
         |> assign_editor_payload(payload)
         |> assign(:stale_draft, false)
         |> assign(:ignore_stale_until_next_render, true)
         |> push_event("seat_map_update", %{map: payload})
         |> put_flash(:info, "Draft saved / Brouillon enregistre")}

      {:error, :stale_draft} ->
        {:noreply,
         socket
         |> assign(:stale_draft, true)
         |> put_flash(:error, "Draft is stale / Ce brouillon n'est plus a jour. Reload or reset the draft before saving.")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}
    end
  end

  def handle_event("publish_preview", %{"map" => map}, socket) do
    with {:ok, _version} <- SeatMapsLogic.save_draft(map, socket.assigns.revision),
         refreshed_payload = load_editor_payload(),
         {:ok, _version} <- SeatMapsLogic.publish_draft(refreshed_payload["revision"]) do
      payload = load_editor_payload()

      {:noreply,
       socket
       |> assign_editor_payload(payload)
       |> assign(:stale_draft, false)
       |> push_event("seat_map_update", %{map: payload})
       |> put_flash(:info, "Published layout activated / Nouveau plan activé")}
    else
      {:error, :stale_draft} ->
        {:noreply,
         socket
         |> assign(:stale_draft, true)
         |> put_flash(:error, "Draft is stale / Ce brouillon n'est plus à jour. Reload or reset the draft before publishing.")}

      {:error, {:active_reservations, seat_slot_ids}} ->
        labels = active_labels(seat_slot_ids) |> Enum.join(", ")

        {:noreply,
         socket
         |> put_flash(:error, "Cannot publish because active seats changed: #{labels} / Publication impossible car des postes actifs ont change.")}

      {:error, changeset = %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("reset_draft", _params, socket) do
    case SeatMapsLogic.reset_draft() do
      {:ok, _draft} ->
        payload = load_editor_payload()

        {:noreply,
         socket
         |> assign_editor_payload(payload)
         |> assign(:stale_draft, false)
         |> push_event("seat_map_update", %{map: payload})
         |> put_flash(:info, "Draft reset from published map / Brouillon reinitialise depuis la carte publiee")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("copy_export_json", _params, socket) do
    {:noreply, push_event(socket, "copy_to_clipboard", %{text: socket.assigns.export_json})}
  end

  def handle_event("assign_team", %{"team_assignment" => params}, socket) do
    case SeatMapsLogic.assign_team_assignment(params) do
      {:ok, _assignment} ->
        payload = load_editor_payload()

        {:noreply,
         socket
         |> assign_editor_payload(payload)
         |> push_event("seat_map_update", %{map: payload})
         |> put_flash(:info, "Team assignment saved / Attribution d'équipe enregistrée")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}
    end
  end

  def handle_event("remove_team_assignment", %{"group_id" => group_id, "tournament_id" => tournament_id}, socket) do
    :ok = SeatMapsLogic.remove_team_assignment(group_id, tournament_id)
    payload = load_editor_payload()

    {:noreply,
     socket
     |> assign_editor_payload(payload)
     |> push_event("seat_map_update", %{map: payload})
     |> put_flash(:info, "Team assignment removed / Attribution d'equipe supprimée")}
  end

  def handle_event("import_json", %{"import" => %{"json" => json}}, socket) do
    with {:ok, decoded} <- Jason.decode(json),
         merged <- Map.put(decoded, "revision", socket.assigns.revision),
         {:ok, _version} <- SeatMapsLogic.save_draft(merged, socket.assigns.revision) do
      payload = load_editor_payload()

      {:noreply,
       socket
       |> assign_editor_payload(payload)
       |> push_event("seat_map_update", %{map: payload})
       |> put_flash(:info, "JSON imported / JSON importé")}
    else
      {:error, %Jason.DecodeError{}} ->
        {:noreply, put_flash(socket, :error, "Invalid JSON / JSON invalide")}

      {:error, :stale_draft} ->
        {:noreply, put_flash(socket, :error, "Draft is stale / Ce brouillon n'est plus à jour")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}
    end
  end

  def handle_event("save_background", %{"background" => params}, socket) do
    payload =
      socket.assigns.map_payload
      |> Map.put("background_kind", params["kind"])
      |> Map.put("background_value", normalize_background_value(params["kind"], params["value"]))
      |> Map.put("revision", socket.assigns.revision)

    case SeatMapsLogic.save_draft(payload, socket.assigns.revision) do
      {:ok, _version} ->
        refreshed = load_editor_payload()

        {:noreply,
         socket
         |> assign_editor_payload(refreshed)
         |> push_event("seat_map_update", %{map: refreshed})
         |> put_flash(:info, "Background updated / Arriere-plan mis a jour")}

      {:error, :stale_draft} ->
        {:noreply, put_flash(socket, :error, "Draft is stale / Ce brouillon n'est plus à jour")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_info({:seat_map_updated, _payload}, socket) do
    payload = load_editor_payload()

    stale_draft =
      payload["revision"] != socket.assigns.revision and
        not socket.assigns[:ignore_stale_until_next_render]

    socket =
      socket
      |> assign(:published_revision, payload["published_revision"] || socket.assigns.published_revision)
      |> assign(:stale_draft, stale_draft)
      |> assign(:ignore_stale_until_next_render, false)

    socket =
      if stale_draft do
        put_flash(socket, :error, "A newer draft or published map is available. Reload or reset before continuing. / Une version plus recente existe.")
      else
        socket
      end

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open">
      <input id="settings-drawer" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content bg-base-100">
        <div class="lg:hidden navbar border-b border-base-300 bg-base-200">
          <label for="settings-drawer" class="btn btn-square btn-ghost text-base-content/60">
            <Icons.menu />
          </label>
          <span class="text-lg font-bold font-mono text-base-content">Seat Map Editor</span>
        </div>

        <div class="p-4 lg:p-6">
          <div class="mb-4 flex items-center justify-between">
            <div>
              <h1 class="text-xl font-bold text-base-content">Seat Map Editor</h1>
              <p class="text-sm text-base-content/60">
                Shift-click to multi-select / Maj-clic pour selection multiple
              </p>
            </div>
            <div class="flex items-center gap-4">
              <div class="flex items-center gap-2">
                <span class="text-tiny uppercase tracking-[0.15em] text-base-content/60">Rev</span>
                <span class="font-mono text-success">{@revision}</span>
              </div>
              <div class="flex items-center gap-2">
                <span class="text-tiny uppercase tracking-[0.15em] text-base-content/60">Published</span>
                <span class="font-mono text-info">{@published_revision}</span>
              </div>
              <%= if @stale_draft do %>
                <div class="rounded border border-warning/50 bg-warning/10 px-3 py-1 text-sm text-warning">
                  Draft is stale
                </div>
              <% end %>
            </div>
          </div>

          <SeatMap.canvas id="editor-seat-map" hook="SeatMapEditor" payload={@map_payload} mode="editor" class="flex-1 min-h-100" stage_class="h-full" phx-ignore>
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
                <button type="button" phx-click="reset_draft" class="btn btn-xs" title="Revert to saved">
                  <Icons.undo_2 class="w-4 h-4" /> Revert
                </button>
                <button type="button" data-seat-map-command="save-draft" class="btn btn-xs btn-success">
                  <Icons.save class="w-4 h-4" /> Save
                </button>
                <button type="button" data-seat-map-command="publish-preview" class="btn btn-xs btn-warning" phx-disable-with="Publishing...">
                  <Icons.send class="w-4 h-4" /> Publish
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
                    <span class="label-text text-tiny uppercase text-base-content/60">Label / Étiquette</span>
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
                <%!-- <p class="text-xs text-base-content/50">Click elsewhere to deselect / Cliquez ailleurs pour désélectionner</p> --%>
              </div>
            </:details>
          </SeatMap.canvas>

          <%!-- Bottom panels --%>
          <div class="grid gap-4 shrink-0 md:grid-cols-2 lg:grid-cols-3">
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
                <Icons.users class="w-4 h-4" /> Tournament Teams
              </h3>
              <div class="space-y-2 mb-3 max-h-32 overflow-y-auto">
                <%= for assignment <- @map_payload.team_assignments || [] do %>
                  <div class="flex items-center justify-between gap-2 rounded border border-base-300 bg-base-100 px-2 py-1.5">
                    <div class="min-w-0">
                      <p class="text-sm font-medium text-base-content truncate">{assignment.team_name}</p>
                      <p class="text-xs text-base-content/60 truncate">{assignment.tournament_name}</p>
                    </div>
                    <button
                      type="button"
                      phx-click="remove_team_assignment"
                      phx-value-group_id={assignment.group_id}
                      phx-value-tournament_id={assignment.tournament_id}
                      class="btn btn-xs btn-ghost btn-square text-error"
                    >
                      <Icons.x class="w-3 h-3" />
                    </button>
                  </div>
                <% end %>
                <%= if Enum.empty?(@map_payload.team_assignments || []) do %>
                  <p class="text-xs text-base-content/50">No team labels</p>
                <% end %>
              </div>
              <.form for={%{}} as={:team_assignment} phx-submit="assign_team" class="space-y-2">
                <select name="team_assignment[group_id]" class="select select-bordered select-sm w-full bg-base-100 text-base-content/70">
                  <%= for group <- @map_payload.groups || [] do %>
                    <option value={group.id} selected={@team_assignment_form["group_id"] == group.id}>{group.name}</option>
                  <% end %>
                </select>
                <div class="flex gap-2">
                  <input
                    name="team_assignment[team_name]"
                    value={@team_assignment_form["team_name"]}
                    class="input input-bordered input-sm flex-1 bg-base-100 text-base-content/70"
                    placeholder="Name"
                  />
                  <input
                    name="team_assignment[color]"
                    value={@team_assignment_form["color"]}
                    class="input input-bordered input-sm w-20 bg-base-100 text-base-content/70"
                    placeholder="#2563eb"
                  />
                </div>
                <button type="submit" class="btn btn-sm w-full btn-ghost text-success hover:bg-success/10">Add</button>
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
        <SettingsNav.settings_nav current_page={:seat_map} is_user_auth={@is_user_auth} />
      </div>
    </div>
    """
  end

  defp load_editor_payload do
    case SeatMapsLogic.get_editor_payload() do
      {:ok, payload} -> payload
      _ -> %{"width" => 1920, "height" => 1080, "meta" => %{}, "seats" => [], "objects" => [], "groups" => [], "team_assignments" => [], "revision" => 1, "published_revision" => 1}
    end
  end

  defp assign_editor_payload(socket, payload) do
    tournaments = TournamentsLogic.get_all_tournaments()
    json_payload = Jason.encode!(payload, pretty: true)

    socket
    |> assign(:map_payload, payload)
    |> assign(:draft_name, payload["name"] || "Working Draft")
    |> assign(:revision, payload["revision"] || 1)
    |> assign(:published_revision, payload["published_revision"] || 1)
    |> assign(:background_kind, payload["background_kind"] || "none")
    |> assign(:export_json, json_payload)
    |> assign(:import_json, json_payload)
    |> assign(:tournaments, tournaments)
    |> assign(:background_value, background_editor_value(payload))
    |> assign(:team_assignment_form, default_team_assignment_form(payload, tournaments))
  end

  defp background_editor_value(%{"background_kind" => "svg", "background_value" => value}) when is_binary(value) do
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
          (socket.assigns.map_payload["seats"] || [])
          |> Enum.map(
            fn seat ->
              if seat["seat_slot_id"] == seat_slot_id do
                Map.merge(seat, updates)
              else
                seat
              end
            end
          )

        updated_payload =
          socket.assigns.map_payload
          |> Map.put("seats", updated_seats)

        {:ok,
         socket
         |> assign(:map_payload, updated_payload)
         |> assign(:selected_seat, Map.merge(selected_seat, updates))
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

  defp default_team_assignment_form(payload, tournaments) do
    first_group = payload["groups"] |> Kernel.||([]) |> List.first()
    first_tournament = tournaments |> Kernel.||([]) |> List.first()

    %{
      "group_id" => first_group && first_group["id"],
      "tournament_id" => first_tournament && first_tournament.id,
      "team_name" => "",
      "color" => (first_group && first_group["color"]) || "#2563eb",
    }
  end

  defp active_labels(seat_slot_ids) do
    case SeatMapsLogic.list_slot_options() do
      {:ok, slots} ->
        slots
        |> Enum.filter(&(&1.id in seat_slot_ids))
        |> Enum.map(& &1.label)

      _ ->
        Enum.map(seat_slot_ids, &to_string/1)
    end
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field} #{&1}") end)
    |> Enum.join(", ")
  end

  defp format_error(other), do: inspect(other)
end
