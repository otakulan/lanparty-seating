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

    {:ok,
     socket
     |> assign(:page_title, "Seat Map Editor")
     |> assign_editor_payload(payload)
     |> assign(:stale_draft, false)
     |> assign(:ignore_stale_until_next_render, false)}
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
    case SeatMapsLogic.save_draft(map, socket.assigns.revision) do
      {:ok, _version} ->
        refreshed_payload = load_editor_payload()

        case SeatMapsLogic.publish_draft(refreshed_payload["revision"]) do
          {:ok, _version} ->
            payload = load_editor_payload()

            {:noreply,
             socket
             |> assign_editor_payload(payload)
             |> assign(:stale_draft, false)
             |> put_flash(:info, "Published layout activated / Mise en page publiee activee")}

          {:error, :stale_draft} ->
            {:noreply,
             socket
             |> assign(:stale_draft, true)
             |> put_flash(:error, "Draft is stale / Ce brouillon n'est plus a jour. Reload or reset the draft before publishing.")}

          {:error, {:active_reservations, seat_slot_ids}} ->
            labels = active_labels(seat_slot_ids)

            {:noreply,
             socket
             |> put_flash(:error, "Cannot publish because active seats changed: #{Enum.join(labels, ", ")} / Publication impossible car des postes actifs ont change.")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, inspect(reason))}
        end

      {:error, :stale_draft} ->
        {:noreply,
         socket
         |> assign(:stale_draft, true)
         |> put_flash(:error, "Draft is stale / Ce brouillon n'est plus a jour. Reload or reset the draft before publishing.")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_error(changeset))}
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
         |> put_flash(:info, "Draft reset from published map / Brouillon reinitialise depuis la carte publiee")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("assign_team", %{"team_assignment" => params}, socket) do
    case SeatMapsLogic.assign_team_assignment(params) do
      {:ok, _assignment} ->
        payload = load_editor_payload()

        {:noreply,
         socket
         |> assign_editor_payload(payload)
         |> put_flash(:info, "Team assignment saved / Attribution d'equipe enregistree")}

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
     |> put_flash(:info, "Team assignment removed / Attribution d'equipe supprimee")}
  end

  def handle_event("import_json", %{"import" => %{"json" => json}}, socket) do
    with {:ok, decoded} <- Jason.decode(json),
         merged <- Map.put(decoded, "revision", socket.assigns.revision),
         {:ok, _version} <- SeatMapsLogic.save_draft(merged, socket.assigns.revision) do
      payload = load_editor_payload()

      {:noreply,
       socket
       |> assign_editor_payload(payload)
       |> put_flash(:info, "JSON imported / JSON importe")}
    else
      {:error, %Jason.DecodeError{}} ->
        {:noreply, put_flash(socket, :error, "Invalid JSON / JSON invalide")}

      {:error, :stale_draft} ->
        {:noreply, put_flash(socket, :error, "Draft is stale / Ce brouillon n'est plus a jour")}

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
         |> put_flash(:info, "Background updated / Arriere-plan mis a jour")}

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
    if assigns.live_action == :poc do
      poc_render(assigns)
    else
      settings_render(assigns)
    end
  end

  defp settings_render(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open" style="font-family: 'JetBrains Mono', 'SF Mono', ui-monospace, Menlo, monospace;">
      <input id="settings-drawer" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content min-h-screen bg-[#0d1117]">
        <div class="lg:hidden navbar border-b border-[#30363d] bg-[#161b22]">
          <label for="settings-drawer" class="btn btn-square btn-ghost text-[#8b949e]">
            <Icons.menu />
          </label>
          <span class="text-lg font-bold text-[#e6edf3]">Seat Map Editor</span>
        </div>

        <div class="p-4 lg:p-6">
          <div class="mb-6 max-w-5xl">
            <div class="mb-2 flex items-center gap-3">
              <div class="h-2 w-2 rounded-full bg-[#22c55e] shadow-[0_0_8px_rgba(34,197,94,0.8)]"></div>
              <h1 class="text-2xl font-bold text-[#e6edf3]">SEAT MAP EDITOR</h1>
            </div>
            <p class="text-sm text-[#8b949e]">
              Proof of concept editor / Editeur preuve de concept
            </p>
          </div>

          <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_22rem]">
            <SeatMap.canvas id="editor-seat-map" hook="SeatMapEditor" payload={@map_payload} mode="editor" class="min-h-[72svh]">
              <:toolbar>
                <button type="button" data-seat-map-command="add-seat" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#22c55e] hover:bg-[#22c55e]/10 hover:border-[#22c55e]">+ Seat</button>
                <button type="button" data-seat-map-command="add-table" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#06b6d4] hover:bg-[#06b6d4]/10 hover:border-[#06b6d4]">+ Table</button>
                <button type="button" data-seat-map-command="add-label" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#f59e0b] hover:bg-[#f59e0b]/10 hover:border-[#f59e0b]">+ Label</button>
                <button type="button" data-seat-map-command="group-selection" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#8b949e] hover:bg-[#8b949e]/10 hover:border-[#8b949e]">
                  Group
                </button>
                <button type="button" data-seat-map-command="delete-selection" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#ef4444] hover:bg-[#ef4444]/10 hover:border-[#ef4444]">
                  DEL
                </button>
                <div class="mx-2 h-4 w-px bg-[#30363d]"></div>
                <button type="button" data-seat-map-command="zoom-out" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#8b949e] hover:bg-[#8b949e]/10">-</button>
                <button type="button" data-seat-map-command="zoom-in" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#8b949e] hover:bg-[#8b949e]/10">+</button>
                <button type="button" data-seat-map-command="reset-view" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#8b949e] hover:bg-[#8b949e]/10">Reset</button>
                <div class="mx-2 h-4 w-px bg-[#30363d]"></div>
                <button type="button" phx-click="reset_draft" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#8b949e] hover:bg-[#8b949e]/10">Reset</button>
                <button type="button" data-seat-map-command="save-draft" class="btn btn-sm border border-[#22c55e] bg-[#22c55e]/10 text-[#22c55e] hover:bg-[#22c55e]/20">Save</button>
                <button type="button" data-seat-map-command="publish-preview" class="btn btn-sm border border-[#f59e0b] bg-[#f59e0b]/10 text-[#f59e0b] hover:bg-[#f59e0b]/20">Publish</button>
              </:toolbar>

              <:details>
                <div class="space-y-3">
                  <div class="flex items-center gap-2">
                    <div class="h-2 w-2 rounded-full bg-[#06b6d4] shadow-[0_0_8px_rgba(6,182,212,0.8)]"></div>
                    <span class="text-[0.65rem] uppercase tracking-[0.2em] text-[#8b949e]">Draft</span>
                  </div>
                  <h2 class="text-xl font-bold text-[#e6edf3]">{@draft_name}</h2>
                  <div class="grid grid-cols-2 gap-2">
                    <div class="rounded border border-[#30363d] bg-[#161b22] px-3 py-2">
                      <span class="text-[0.6rem] uppercase tracking-[0.15em] text-[#8b949e]">Rev</span>
                      <span class="ml-2 font-mono text-[#22c55e]">{@revision}</span>
                    </div>
                    <div class="rounded border border-[#30363d] bg-[#161b22] px-3 py-2">
                      <span class="text-[0.6rem] uppercase tracking-[0.15em] text-[#8b949e]">Published</span>
                      <span class="ml-2 font-mono text-[#06b6d4]">{@published_revision}</span>
                    </div>
                  </div>
                  <div class="grid grid-cols-2 gap-2">
                    <div class="rounded border border-[#30363d] bg-[#161b22] px-3 py-2">
                      <span class="text-[0.6rem] uppercase tracking-[0.15em] text-[#8b949e]">Width</span>
                      <span class="ml-2 font-mono text-[#e6edf3]">{@map_payload["width"]}</span>
                    </div>
                    <div class="rounded border border-[#30363d] bg-[#161b22] px-3 py-2">
                      <span class="text-[0.6rem] uppercase tracking-[0.15em] text-[#8b949e]">Height</span>
                      <span class="ml-2 font-mono text-[#e6edf3]">{@map_payload["height"]}</span>
                    </div>
                  </div>
                  <%= if @stale_draft do %>
                    <div class="rounded border border-[#f59e0b]/50 bg-[#f59e0b]/10 px-3 py-2 text-sm text-[#fbbf24]">
                      Draft is stale / Brouillon obsolete
                    </div>
                  <% end %>
                  <p class="text-xs text-[#8b949e]">Shift-click to multi-select / Maj-clic pour selection multiple</p>
                </div>
              </:details>
            </SeatMap.canvas>

            <div class="space-y-4">
              <div class="rounded-lg border border-[#30363d] bg-[#161b22] p-4">
                <div class="flex items-center gap-2 mb-3">
                  <div class="h-1.5 w-1.5 rounded-full bg-[#22c55e]"></div>
                  <span class="text-[0.65rem] uppercase tracking-[0.2em] text-[#8b949e]">Export JSON</span>
                </div>
                <textarea
                  data-seat-map-export-for="editor-seat-map"
                  class="textarea textarea-bordered h-[20rem] w-full border-[#30363d] bg-[#0d1117] font-mono text-xs text-[#8b949e] placeholder:text-[#6e7681] focus:border-[#06b6d4]"
                  readonly
                >{@export_json}</textarea>
              </div>

              <div class="rounded-lg border border-[#30363d] bg-[#161b22] p-4">
                <div class="flex items-center gap-2 mb-3">
                  <div class="h-1.5 w-1.5 rounded-full bg-[#06b6d4]"></div>
                  <span class="text-[0.65rem] uppercase tracking-[0.2em] text-[#8b949e]">Import JSON</span>
                </div>
                <.form for={%{}} as={:import} phx-submit="import_json" class="space-y-3">
                  <textarea
                    name="import[json]"
                    class="textarea textarea-bordered h-36 w-full border-[#30363d] bg-[#0d1117] font-mono text-xs text-[#8b949e] placeholder:text-[#6e7681] focus:border-[#06b6d4]"
                  ><%= @import_json %></textarea>
                  <button type="submit" class="btn btn-sm w-full border border-[#06b6d4] bg-[#06b6d4]/10 text-[#06b6d4] hover:bg-[#06b6d4]/20">Import</button>
                </.form>
              </div>

              <div class="rounded-lg border border-[#30363d] bg-[#161b22] p-4">
                <div class="flex items-center gap-2 mb-3">
                  <div class="h-1.5 w-1.5 rounded-full bg-[#f59e0b]"></div>
                  <span class="text-[0.65rem] uppercase tracking-[0.2em] text-[#8b949e]">Background</span>
                </div>
                <.form for={%{}} as={:background} phx-submit="save_background" class="space-y-3">
                  <select name="background[kind]" class="select select-bordered w-full border-[#30363d] bg-[#0d1117] text-[#8b949e] focus:border-[#06b6d4]">
                    <option value="none" selected={@background_kind == "none"}>None</option>
                    <option value="svg" selected={@background_kind == "svg"}>Inline SVG / SVG data</option>
                    <option value="image" selected={@background_kind == "image"}>Image URL / data URL</option>
                  </select>
                  <textarea
                    name="background[value]"
                    class="textarea textarea-bordered h-24 w-full border-[#30363d] bg-[#0d1117] font-mono text-xs text-[#8b949e] placeholder:text-[#6e7681] focus:border-[#06b6d4]"
                  ><%= @background_value %></textarea>
                  <button type="submit" class="btn btn-sm w-full border border-[#f59e0b] bg-[#f59e0b]/10 text-[#f59e0b] hover:bg-[#f59e0b]/20">Update</button>
                </.form>
              </div>

              <div class="rounded-lg border border-[#30363d] bg-[#161b22] p-4">
                <div class="flex items-center gap-2 mb-3">
                  <div class="h-1.5 w-1.5 rounded-full bg-[#22c55e]"></div>
                  <span class="text-[0.65rem] uppercase tracking-[0.2em] text-[#8b949e]">Tournament Teams</span>
                </div>

                <div class="space-y-2 mb-4">
                  <%= for assignment <- @map_payload["team_assignments"] || [] do %>
                    <div class="flex items-center justify-between gap-3 rounded border border-[#30363d] bg-[#0d1117] px-3 py-2">
                      <div>
                        <p class="font-semibold text-[#e6edf3]">{assignment["team_name"]}</p>
                        <p class="text-xs text-[#8b949e]">{assignment["tournament_name"]} · {assignment["group_id"]}</p>
                      </div>
                      <button
                        type="button"
                        phx-click="remove_team_assignment"
                        phx-value-group_id={assignment["group_id"]}
                        phx-value-tournament_id={assignment["tournament_id"]}
                        class="btn btn-xs border border-[#ef4444] bg-[#ef4444]/10 text-[#ef4444] hover:bg-[#ef4444]/20"
                      >
                        Remove
                      </button>
                    </div>
                  <% end %>

                  <%= if Enum.empty?(@map_payload["team_assignments"] || []) do %>
                    <p class="rounded border border-[#30363d] bg-[#0d1117] px-3 py-2 text-sm text-[#8b949e]">No tournament team labels yet</p>
                  <% end %>
                </div>

                <.form for={%{}} as={:team_assignment} phx-submit="assign_team" class="space-y-3">
                  <select name="team_assignment[group_id]" class="select select-bordered w-full border-[#30363d] bg-[#0d1117] text-[#8b949e] focus:border-[#06b6d4]">
                    <%= for group <- @map_payload["groups"] || [] do %>
                      <option value={group["id"]} selected={@team_assignment_form["group_id"] == group["id"]}>{group["name"]}</option>
                    <% end %>
                  </select>
                  <select name="team_assignment[tournament_id]" class="select select-bordered w-full border-[#30363d] bg-[#0d1117] text-[#8b949e] focus:border-[#06b6d4]">
                    <%= for tournament <- @tournaments do %>
                      <option value={tournament.id} selected={to_string(@team_assignment_form["tournament_id"]) == to_string(tournament.id)}>{tournament.name}</option>
                    <% end %>
                  </select>
                  <input
                    name="team_assignment[team_name]"
                    value={@team_assignment_form["team_name"]}
                    class="input input-bordered w-full border-[#30363d] bg-[#0d1117] text-[#8b949e] placeholder:text-[#6e7681] focus:border-[#06b6d4]"
                    placeholder="Team name"
                  />
                  <input
                    name="team_assignment[color]"
                    value={@team_assignment_form["color"]}
                    class="input input-bordered w-full border-[#30363d] bg-[#0d1117] text-[#8b949e] placeholder:text-[#6e7681] focus:border-[#06b6d4]"
                    placeholder="#2563eb"
                  />
                  <button type="submit" class="btn btn-sm w-full border border-[#22c55e] bg-[#22c55e]/10 text-[#22c55e] hover:bg-[#22c55e]/20">Save</button>
                </.form>
              </div>

              <div class="rounded-lg border border-[#30363d] bg-[#161b22] p-4">
                <SeatMap.legend />
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

  defp poc_render(assigns) do
    ~H"""
    <div
      class="min-h-screen bg-[#0d1117] px-4 py-4 md:px-6 md:py-6"
      style="font-family: 'JetBrains Mono', 'SF Mono', ui-monospace, Menlo, monospace;"
    >
      <div class="mb-6 max-w-5xl">
        <div class="mb-2 flex items-center gap-3">
          <div class="h-2 w-2 rounded-full bg-[#22c55e] shadow-[0_0_8px_rgba(34,197,94,0.8)]"></div>
          <h1 class="text-2xl font-bold text-[#e6edf3]">SEAT MAP EDITOR</h1>
        </div>
        <p class="text-sm text-[#8b949e]">
          Public proof of concept / Preuve de concept publique
        </p>
      </div>

      <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_22rem]">
        <SeatMap.canvas id="editor-seat-map" hook="SeatMapEditor" payload={@map_payload} mode="editor" class="min-h-[78svh]">
          <:toolbar>
            <button type="button" data-seat-map-command="add-seat" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#22c55e] hover:bg-[#22c55e]/10 hover:border-[#22c55e]">+ Seat</button>
            <button type="button" data-seat-map-command="add-table" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#06b6d4] hover:bg-[#06b6d4]/10 hover:border-[#06b6d4]">+ Table</button>
            <button type="button" data-seat-map-command="add-label" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#f59e0b] hover:bg-[#f59e0b]/10 hover:border-[#f59e0b]">+ Label</button>
            <button type="button" data-seat-map-command="group-selection" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#8b949e] hover:bg-[#8b949e]/10 hover:border-[#8b949e]">Group</button>
            <button type="button" data-seat-map-command="delete-selection" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#ef4444] hover:bg-[#ef4444]/10 hover:border-[#ef4444]">DEL</button>
            <div class="mx-2 h-4 w-px bg-[#30363d]"></div>
            <button type="button" data-seat-map-command="zoom-out" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#8b949e] hover:bg-[#8b949e]/10">-</button>
            <button type="button" data-seat-map-command="zoom-in" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#8b949e] hover:bg-[#8b949e]/10">+</button>
            <button type="button" data-seat-map-command="reset-view" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#8b949e] hover:bg-[#8b949e]/10">Reset</button>
            <div class="mx-2 h-4 w-px bg-[#30363d]"></div>
            <button type="button" phx-click="reset_draft" class="btn btn-sm border border-[#30363d] bg-[#161b22] text-[#8b949e] hover:bg-[#8b949e]/10">Reset</button>
            <button type="button" data-seat-map-command="save-draft" class="btn btn-sm border border-[#22c55e] bg-[#22c55e]/10 text-[#22c55e] hover:bg-[#22c55e]/20">Save</button>
            <button type="button" data-seat-map-command="publish-preview" class="btn btn-sm border border-[#f59e0b] bg-[#f59e0b]/10 text-[#f59e0b] hover:bg-[#f59e0b]/20">Publish</button>
          </:toolbar>

          <:details>
            <div class="space-y-3">
              <div class="flex items-center gap-2">
                <div class="h-2 w-2 rounded-full bg-[#06b6d4] shadow-[0_0_8px_rgba(6,182,212,0.8)]"></div>
                <span class="text-[0.65rem] uppercase tracking-[0.2em] text-[#8b949e]">Draft</span>
              </div>
              <h2 class="text-xl font-bold text-[#e6edf3]">{@draft_name}</h2>
              <div class="grid grid-cols-2 gap-2">
                <div class="rounded border border-[#30363d] bg-[#161b22] px-3 py-2">
                  <span class="text-[0.6rem] uppercase tracking-[0.15em] text-[#8b949e]">Rev</span>
                  <span class="ml-2 font-mono text-[#22c55e]">{@revision}</span>
                </div>
                <div class="rounded border border-[#30363d] bg-[#161b22] px-3 py-2">
                  <span class="text-[0.6rem] uppercase tracking-[0.15em] text-[#8b949e]">Published</span>
                  <span class="ml-2 font-mono text-[#06b6d4]">{@published_revision}</span>
                </div>
              </div>
              <%= if @stale_draft do %>
                <div class="rounded border border-[#f59e0b]/50 bg-[#f59e0b]/10 px-3 py-2 text-sm text-[#fbbf24]">
                  Draft is stale / Brouillon obsolete
                </div>
              <% end %>
              <p class="text-xs text-[#8b949e]">Shift-click to multi-select / Maj-clic pour selection multiple</p>
            </div>
          </:details>
        </SeatMap.canvas>

        <div class="space-y-4">
          <div class="rounded-lg border border-[#30363d] bg-[#161b22] p-4">
            <div class="flex items-center gap-2 mb-3">
              <div class="h-1.5 w-1.5 rounded-full bg-[#22c55e]"></div>
              <span class="text-[0.65rem] uppercase tracking-[0.2em] text-[#8b949e]">Export JSON</span>
            </div>
            <textarea
              data-seat-map-export-for="editor-seat-map"
              class="textarea textarea-bordered h-[20rem] w-full border-[#30363d] bg-[#0d1117] font-mono text-xs text-[#8b949e] placeholder:text-[#6e7681] focus:border-[#06b6d4]"
              readonly
            >{@export_json}</textarea>
          </div>

          <div class="rounded-lg border border-[#30363d] bg-[#161b22] p-4">
            <div class="flex items-center gap-2 mb-3">
              <div class="h-1.5 w-1.5 rounded-full bg-[#06b6d4]"></div>
              <span class="text-[0.65rem] uppercase tracking-[0.2em] text-[#8b949e]">Import JSON</span>
            </div>
            <.form for={%{}} as={:import} phx-submit="import_json" class="space-y-3">
              <textarea name="import[json]" class="textarea textarea-bordered h-36 w-full border-[#30363d] bg-[#0d1117] font-mono text-xs text-[#8b949e] placeholder:text-[#6e7681] focus:border-[#06b6d4]"><%= @import_json %></textarea>
              <button type="submit" class="btn btn-sm w-full border border-[#06b6d4] bg-[#06b6d4]/10 text-[#06b6d4] hover:bg-[#06b6d4]/20">Import</button>
            </.form>
          </div>

          <div class="rounded-lg border border-[#30363d] bg-[#161b22] p-4">
            <div class="flex items-center gap-2 mb-3">
              <div class="h-1.5 w-1.5 rounded-full bg-[#f59e0b]"></div>
              <span class="text-[0.65rem] uppercase tracking-[0.2em] text-[#8b949e]">Background</span>
            </div>
            <.form for={%{}} as={:background} phx-submit="save_background" class="space-y-3">
              <select name="background[kind]" class="select select-bordered w-full border-[#30363d] bg-[#0d1117] text-[#8b949e] focus:border-[#06b6d4]">
                <option value="none" selected={@background_kind == "none"}>None</option>
                <option value="svg" selected={@background_kind == "svg"}>Inline SVG / SVG data</option>
                <option value="image" selected={@background_kind == "image"}>Image URL / data URL</option>
              </select>
              <textarea
                name="background[value]"
                class="textarea textarea-bordered h-24 w-full border-[#30363d] bg-[#0d1117] font-mono text-xs text-[#8b949e] placeholder:text-[#6e7681] focus:border-[#06b6d4]"
              ><%= @background_value %></textarea>
              <button type="submit" class="btn btn-sm w-full border border-[#f59e0b] bg-[#f59e0b]/10 text-[#f59e0b] hover:bg-[#f59e0b]/20">Update</button>
            </.form>
          </div>

          <div class="rounded-lg border border-[#30363d] bg-[#161b22] p-4">
            <div class="flex items-center gap-2 mb-3">
              <div class="h-1.5 w-1.5 rounded-full bg-[#22c55e]"></div>
              <span class="text-[0.65rem] uppercase tracking-[0.2em] text-[#8b949e]">Tournament Teams</span>
            </div>

            <div class="space-y-2 mb-4">
              <%= for assignment <- @map_payload["team_assignments"] || [] do %>
                <div class="flex items-center justify-between gap-3 rounded border border-[#30363d] bg-[#0d1117] px-3 py-2">
                  <div>
                    <p class="font-semibold text-[#e6edf3]">{assignment["team_name"]}</p>
                    <p class="text-xs text-[#8b949e]">{assignment["tournament_name"]} · {assignment["group_id"]}</p>
                  </div>
                  <button
                    type="button"
                    phx-click="remove_team_assignment"
                    phx-value-group_id={assignment["group_id"]}
                    phx-value-tournament_id={assignment["tournament_id"]}
                    class="btn btn-xs border border-[#ef4444] bg-[#ef4444]/10 text-[#ef4444] hover:bg-[#ef4444]/20"
                  >
                    Remove
                  </button>
                </div>
              <% end %>

              <%= if Enum.empty?(@map_payload["team_assignments"] || []) do %>
                <p class="rounded border border-[#30363d] bg-[#0d1117] px-3 py-2 text-sm text-[#8b949e]">No tournament team labels yet</p>
              <% end %>
            </div>

            <.form for={%{}} as={:team_assignment} phx-submit="assign_team" class="space-y-3">
              <select name="team_assignment[group_id]" class="select select-bordered w-full border-[#30363d] bg-[#0d1117] text-[#8b949e] focus:border-[#06b6d4]">
                <%= for group <- @map_payload["groups"] || [] do %>
                  <option value={group["id"]} selected={@team_assignment_form["group_id"] == group["id"]}>{group["name"]}</option>
                <% end %>
              </select>
              <select name="team_assignment[tournament_id]" class="select select-bordered w-full border-[#30363d] bg-[#0d1117] text-[#8b949e] focus:border-[#06b6d4]">
                <%= for tournament <- @tournaments do %>
                  <option value={tournament.id} selected={to_string(@team_assignment_form["tournament_id"]) == to_string(tournament.id)}>{tournament.name}</option>
                <% end %>
              </select>
              <input
                name="team_assignment[team_name]"
                value={@team_assignment_form["team_name"]}
                class="input input-bordered w-full border-[#30363d] bg-[#0d1117] text-[#8b949e] placeholder:text-[#6e7681] focus:border-[#06b6d4]"
                placeholder="Team name"
              />
              <input
                name="team_assignment[color]"
                value={@team_assignment_form["color"]}
                class="input input-bordered w-full border-[#30363d] bg-[#0d1117] text-[#8b949e] placeholder:text-[#6e7681] focus:border-[#06b6d4]"
                placeholder="#2563eb"
              />
              <button type="submit" class="btn btn-sm w-full border border-[#22c55e] bg-[#22c55e]/10 text-[#22c55e] hover:bg-[#22c55e]/20">Save</button>
            </.form>
          </div>

          <div class="rounded-lg border border-[#30363d] bg-[#161b22] p-4">
            <SeatMap.legend />
          </div>
        </div>
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
    socket
    |> assign(:map_payload, payload)
    |> assign(:export_json, Jason.encode!(payload, pretty: true))
    |> assign(:draft_name, payload["name"] || "Working Draft")
    |> assign(:revision, payload["revision"] || 1)
    |> assign(:published_revision, payload["published_revision"] || 1)
    |> assign(:import_json, Jason.encode!(payload, pretty: true))
    |> assign(:tournaments, TournamentsLogic.get_all_tournaments())
    |> assign(:background_kind, payload["background_kind"] || "none")
    |> assign(:background_value, background_editor_value(payload))
    |> assign(:team_assignment_form, default_team_assignment_form(payload, TournamentsLogic.get_all_tournaments()))
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

  defp background_editor_value(%{"background_value" => value}) when is_binary(value), do: value
  defp background_editor_value(_payload), do: ""

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
