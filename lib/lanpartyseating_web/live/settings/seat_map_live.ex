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
     |> assign(:stale_draft, false)}
  end

  def handle_event("save_draft_preview", %{"map" => %{"revision" => revision} = map}, socket) do
    case SeatMapsLogic.save_draft(map, revision) do
      {:ok, _version} ->
        payload = load_editor_payload()

        {:noreply,
         socket
         |> assign_editor_payload(payload)
         |> assign(:stale_draft, false)
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
    stale_draft = payload["revision"] != socket.assigns.revision

    socket =
      socket
      |> assign(:published_revision, payload["published_revision"] || socket.assigns.published_revision)
      |> assign(:stale_draft, stale_draft)

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
    <div class="drawer lg:drawer-open" style="font-family: 'SF Pro Display', 'SF Pro Text', -apple-system, BlinkMacSystemFont, sans-serif;">
      <input id="settings-drawer" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content bg-[linear-gradient(180deg,#faf6ef_0%,#f4eee2_100%)]">
        <div class="lg:hidden navbar border-b border-base-300 bg-base-200">
          <label for="settings-drawer" class="btn btn-square btn-ghost">
            <Icons.menu />
          </label>
          <span class="text-lg font-bold">Seat Map Editor</span>
        </div>

        <div class="p-4 lg:p-6">
          <div class="mb-6 max-w-5xl">
            <.page_header
              title="Seat Map Editor"
              subtitle="Proof of concept editor / Editeur preuve de concept"
            />

            <div class="rounded-[28px] border border-white/70 bg-white/78 p-5 text-sm leading-6 text-[#4a5963] shadow-[0_24px_70px_rgba(60,47,31,0.08)] backdrop-blur-xl">
              <p>
                This editor is intentionally non-collaborative. If a newer draft exists, saving is rejected as stale.
                / Cet editeur n'est pas collaboratif. Si un brouillon plus recent existe, l'enregistrement est refuse comme obsolete.
              </p>
              <p class="mt-2">
                One published seat map remains active at a time. Draft deletion and named drafts will be part of the backend phase.
                / Une seule carte publiee reste active a la fois. La suppression et le nommage des brouillons viendront dans la phase backend.
              </p>
            </div>
          </div>

          <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_22rem]">
            <SeatMap.canvas id="editor-seat-map" hook="SeatMapEditor" payload={@map_payload} mode="editor" class="min-h-[72svh]">
              <:toolbar>
                <button type="button" data-seat-map-command="add-seat" class="btn btn-sm rounded-2xl border-0 bg-[#2f4350] text-white shadow-none hover:bg-[#24343e]">Add Seat</button>
                <button type="button" data-seat-map-command="add-table" class="btn btn-sm rounded-2xl border-0 bg-[#e8d6bd] text-[#5d4637] shadow-none hover:bg-[#dcc5a5]">Add Table</button>
                <button type="button" data-seat-map-command="add-label" class="btn btn-sm rounded-2xl border-0 bg-[#dce8f5] text-[#2d557a] shadow-none hover:bg-[#cdddf0]">Add Label</button>
                <button type="button" data-seat-map-command="group-selection" class="btn btn-sm rounded-2xl border-0 bg-[#d9ead4] text-[#2f5732] shadow-none hover:bg-[#cadec5]">Group Seats</button>
                <button type="button" data-seat-map-command="delete-selection" class="btn btn-sm rounded-2xl border-0 bg-[#f5dde1] text-[#8a3240] shadow-none hover:bg-[#efced5]">Delete</button>
                <button type="button" data-seat-map-command="zoom-out" class="btn btn-sm rounded-2xl border-0 bg-[#f3ece1] text-[#31424d] shadow-none hover:bg-[#eadfce]">-</button>
                <button type="button" data-seat-map-command="zoom-in" class="btn btn-sm rounded-2xl border-0 bg-[#f3ece1] text-[#31424d] shadow-none hover:bg-[#eadfce]">+</button>
                <button type="button" data-seat-map-command="reset-view" class="btn btn-sm rounded-2xl border-0 bg-[#2f4350] text-white shadow-none hover:bg-[#24343e]">Reset</button>
                <button type="button" phx-click="reset_draft" class="btn btn-sm rounded-2xl border-0 bg-[#ece7e0] text-[#4d5c66] shadow-none hover:bg-[#e1dad2]">Reset Draft</button>
                <button type="button" data-seat-map-command="save-draft" class="btn btn-sm rounded-2xl border-0 bg-[#2d9c8f] text-white shadow-none hover:bg-[#218175]">Save Draft</button>
                <button type="button" data-seat-map-command="publish-preview" class="btn btn-sm rounded-2xl border-0 bg-[#c27a35] text-white shadow-none hover:bg-[#aa6728]">Publish</button>
              </:toolbar>

              <:details>
                <div class="space-y-3 text-sm text-[#40505a]">
                  <div>
                    <p class="text-[0.68rem] uppercase tracking-[0.24em] text-[#7b6d5d]">Draft</p>
                    <h2 class="text-[2rem] font-semibold tracking-[-0.05em] text-[#26333b]">{@draft_name}</h2>
                  </div>
                  <div class="grid grid-cols-2 gap-3 text-xs uppercase tracking-[0.16em] text-[#6d7a81]">
                    <div class="rounded-2xl bg-[#f6f0e6] px-3 py-2">Revision {@revision}</div>
                    <div class="rounded-2xl bg-[#edf4f1] px-3 py-2">Published rev {@published_revision}</div>
                  </div>
                  <%= if @stale_draft do %>
                    <p class="rounded-2xl bg-[#fff3e8] px-3 py-2 text-[#8c5614]">Draft is stale / Brouillon obsolete</p>
                  <% end %>
                  <p>Shift-click multiple seats, then create a group. / Maj-clic pour plusieurs postes, puis creez un groupe.</p>
                </div>
              </:details>
            </SeatMap.canvas>

            <div class="space-y-4">
              <div class="rounded-[28px] border border-white/80 bg-white/82 p-5 shadow-[0_24px_70px_rgba(60,47,31,0.08)] backdrop-blur-xl">
                <div class="flex items-center justify-between gap-3">
                  <div>
                    <p class="text-[0.68rem] uppercase tracking-[0.24em] text-[#7b6d5d]">Draft JSON</p>
                    <h3 class="text-xl font-black tracking-tight text-[#26333b]">Export / Exporter</h3>
                  </div>
                </div>

                <textarea
                  data-seat-map-export-for="editor-seat-map"
                  class="textarea textarea-bordered mt-4 h-[30rem] w-full font-mono text-xs leading-5"
                  readonly
                >{@export_json}</textarea>
              </div>

              <div class="rounded-[28px] border border-white/80 bg-white/82 p-5 shadow-[0_24px_70px_rgba(60,47,31,0.08)] backdrop-blur-xl">
                <p class="text-[0.68rem] uppercase tracking-[0.24em] text-[#7b6d5d]">Import JSON</p>
                <h3 class="text-xl font-black tracking-tight text-[#26333b]">Import / Importer</h3>

                <.form for={%{}} as={:import} phx-submit="import_json" class="mt-4 space-y-3">
                  <textarea name="import[json]" class="textarea textarea-bordered h-48 w-full font-mono text-xs leading-5"><%= @import_json %></textarea>
                  <button type="submit" class="btn btn-sm rounded-2xl border-0 bg-[#2f4350] text-white shadow-none hover:bg-[#24343e]">Apply Import</button>
                </.form>
              </div>

              <div class="rounded-[28px] border border-white/80 bg-white/82 p-5 shadow-[0_24px_70px_rgba(60,47,31,0.08)] backdrop-blur-xl">
                <p class="text-[0.68rem] uppercase tracking-[0.24em] text-[#7b6d5d]">Background</p>
                <h3 class="text-xl font-black tracking-tight text-[#26333b]">SVG / Image</h3>

                <.form for={%{}} as={:background} phx-submit="save_background" class="mt-4 space-y-3">
                  <select name="background[kind]" class="select select-bordered w-full">
                    <option value="none" selected={@background_kind == "none"}>None</option>
                    <option value="svg" selected={@background_kind == "svg"}>Inline SVG / SVG data</option>
                    <option value="image" selected={@background_kind == "image"}>Image URL / data URL</option>
                  </select>
                  <textarea name="background[value]" class="textarea textarea-bordered h-36 w-full font-mono text-xs leading-5"><%= @background_value %></textarea>
                  <button type="submit" class="btn btn-sm rounded-2xl border-0 bg-[#2f4350] text-white shadow-none hover:bg-[#24343e]">Update Background</button>
                </.form>
              </div>

              <div class="rounded-[28px] border border-white/80 bg-white/82 p-5 shadow-[0_24px_70px_rgba(60,47,31,0.08)] backdrop-blur-xl">
                <p class="text-[0.68rem] uppercase tracking-[0.24em] text-[#7b6d5d]">Tournament Teams</p>
                <h3 class="text-xl font-black tracking-tight text-[#26333b]">Assignments / Attributions</h3>

                <div class="mt-4 space-y-2">
                  <%= for assignment <- @map_payload["team_assignments"] || [] do %>
                    <div class="flex items-center justify-between gap-3 rounded-2xl bg-[#f6f2ea] px-3 py-3 text-sm">
                      <div>
                        <p class="font-semibold text-[#26333b]">{assignment["team_name"]}</p>
                        <p class="text-xs uppercase tracking-[0.16em] text-[#7b6d5d]">{assignment["tournament_name"]} · {assignment["group_id"]}</p>
                      </div>
                      <button
                        type="button"
                        phx-click="remove_team_assignment"
                        phx-value-group_id={assignment["group_id"]}
                        phx-value-tournament_id={assignment["tournament_id"]}
                        class="btn btn-xs rounded-full border-0 bg-[#f5dde1] text-[#8a3240] shadow-none hover:bg-[#efced5]"
                      >
                        Remove
                      </button>
                    </div>
                  <% end %>

                  <%= if Enum.empty?(@map_payload["team_assignments"] || []) do %>
                    <p class="rounded-2xl bg-[#f6f2ea] px-3 py-3 text-sm text-[#5a6871]">No tournament team labels yet / Aucune etiquette d'equipe pour le moment.</p>
                  <% end %>
                </div>

                <.form for={%{}} as={:team_assignment} phx-submit="assign_team" class="mt-4 space-y-3">
                  <select name="team_assignment[group_id]" class="select select-bordered w-full">
                    <%= for group <- @map_payload["groups"] || [] do %>
                      <option value={group["id"]} selected={@team_assignment_form["group_id"] == group["id"]}>{group["name"]}</option>
                    <% end %>
                  </select>
                  <select name="team_assignment[tournament_id]" class="select select-bordered w-full">
                    <%= for tournament <- @tournaments do %>
                      <option value={tournament.id} selected={to_string(@team_assignment_form["tournament_id"]) == to_string(tournament.id)}>{tournament.name}</option>
                    <% end %>
                  </select>
                  <input name="team_assignment[team_name]" value={@team_assignment_form["team_name"]} class="input input-bordered w-full" placeholder="Team name" />
                  <input name="team_assignment[color]" value={@team_assignment_form["color"]} class="input input-bordered w-full" placeholder="#2563eb" />
                  <button type="submit" class="btn btn-sm rounded-2xl border-0 bg-[#2f4350] text-white shadow-none hover:bg-[#24343e]">Save Team Label</button>
                </.form>
              </div>

              <div class="rounded-[28px] border border-white/80 bg-white/82 p-5 shadow-[0_24px_70px_rgba(60,47,31,0.08)] backdrop-blur-xl">
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
      class="min-h-screen bg-[linear-gradient(180deg,#faf6ef_0%,#f4eee2_100%)] px-4 py-4 md:px-6 md:py-6"
      style="font-family: 'SF Pro Display', 'SF Pro Text', -apple-system, BlinkMacSystemFont, sans-serif;"
    >
      <div class="mb-6 max-w-5xl">
        <.page_header
          title="Seat Map Editor"
          subtitle="Public proof of concept / Preuve de concept publique"
        />

        <div class="rounded-[28px] border border-white/75 bg-white/80 p-5 text-sm leading-6 text-[#4a5963] shadow-[0_24px_70px_rgba(60,47,31,0.08)] backdrop-blur-xl">
          <p>
            Konva editor proof of concept with local draft state, pushEvent-driven save/publish actions, and stale draft messaging.
            / Preuve de concept Konva avec brouillon local, sauvegarde/publication via pushEvent et message de brouillon obsolete.
          </p>
        </div>
      </div>

      <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_22rem]">
        <SeatMap.canvas id="editor-seat-map" hook="SeatMapEditor" payload={@map_payload} mode="editor" class="min-h-[78svh]">
          <:toolbar>
            <button type="button" data-seat-map-command="add-seat" class="btn btn-sm rounded-2xl border-0 bg-[#2f4350] text-white shadow-none hover:bg-[#24343e]">Add Seat</button>
            <button type="button" data-seat-map-command="add-table" class="btn btn-sm rounded-2xl border-0 bg-[#e8d6bd] text-[#5d4637] shadow-none hover:bg-[#dcc5a5]">Add Table</button>
            <button type="button" data-seat-map-command="add-label" class="btn btn-sm rounded-2xl border-0 bg-[#dce8f5] text-[#2d557a] shadow-none hover:bg-[#cdddf0]">Add Label</button>
            <button type="button" data-seat-map-command="group-selection" class="btn btn-sm rounded-2xl border-0 bg-[#d9ead4] text-[#2f5732] shadow-none hover:bg-[#cadec5]">Group Seats</button>
            <button type="button" data-seat-map-command="delete-selection" class="btn btn-sm rounded-2xl border-0 bg-[#f5dde1] text-[#8a3240] shadow-none hover:bg-[#efced5]">Delete</button>
            <button type="button" data-seat-map-command="zoom-out" class="btn btn-sm rounded-2xl border-0 bg-[#f3ece1] text-[#31424d] shadow-none hover:bg-[#eadfce]">-</button>
            <button type="button" data-seat-map-command="zoom-in" class="btn btn-sm rounded-2xl border-0 bg-[#f3ece1] text-[#31424d] shadow-none hover:bg-[#eadfce]">+</button>
            <button type="button" data-seat-map-command="reset-view" class="btn btn-sm rounded-2xl border-0 bg-[#2f4350] text-white shadow-none hover:bg-[#24343e]">Reset</button>
            <button type="button" phx-click="reset_draft" class="btn btn-sm rounded-2xl border-0 bg-[#ece7e0] text-[#4d5c66] shadow-none hover:bg-[#e1dad2]">Reset Draft</button>
            <button type="button" data-seat-map-command="save-draft" class="btn btn-sm rounded-2xl border-0 bg-[#2d9c8f] text-white shadow-none hover:bg-[#218175]">Save Draft</button>
            <button type="button" data-seat-map-command="publish-preview" class="btn btn-sm rounded-2xl border-0 bg-[#c27a35] text-white shadow-none hover:bg-[#aa6728]">Publish</button>
          </:toolbar>

          <:details>
            <div class="space-y-3 text-sm text-[#40505a]">
              <div>
                <p class="text-[0.68rem] uppercase tracking-[0.24em] text-[#7b6d5d]">Draft</p>
                <h2 class="text-[2rem] font-semibold tracking-[-0.05em] text-[#26333b]">{@draft_name}</h2>
              </div>
              <div class="grid grid-cols-2 gap-3 text-xs uppercase tracking-[0.16em] text-[#6d7a81]">
                <div class="rounded-2xl bg-[#f6f0e6] px-3 py-2">Revision {@revision}</div>
                <div class="rounded-2xl bg-[#edf4f1] px-3 py-2">Published rev {@published_revision}</div>
              </div>
              <%= if @stale_draft do %>
                <p class="rounded-2xl bg-[#fff3e8] px-3 py-2 text-[#8c5614]">Draft is stale / Brouillon obsolete</p>
              <% end %>
              <p>Shift-click multiple seats, then create a group. / Maj-clic pour plusieurs postes, puis creez un groupe.</p>
            </div>
          </:details>
        </SeatMap.canvas>

        <div class="space-y-4">
          <div class="rounded-[28px] border border-white/80 bg-white/82 p-5 shadow-[0_24px_70px_rgba(60,47,31,0.08)] backdrop-blur-xl">
            <div>
              <p class="text-[0.68rem] uppercase tracking-[0.24em] text-[#7b6d5d]">Draft JSON</p>
              <h3 class="text-xl font-black tracking-tight text-[#26333b]">Export / Exporter</h3>
            </div>

            <textarea
              data-seat-map-export-for="editor-seat-map"
              class="textarea textarea-bordered mt-4 h-[30rem] w-full font-mono text-xs leading-5"
              readonly
            >{@export_json}</textarea>
          </div>

          <div class="rounded-[28px] border border-white/80 bg-white/82 p-5 shadow-[0_24px_70px_rgba(60,47,31,0.08)] backdrop-blur-xl">
            <p class="text-[0.68rem] uppercase tracking-[0.24em] text-[#7b6d5d]">Import JSON</p>
            <h3 class="text-xl font-black tracking-tight text-[#26333b]">Import / Importer</h3>

            <.form for={%{}} as={:import} phx-submit="import_json" class="mt-4 space-y-3">
              <textarea name="import[json]" class="textarea textarea-bordered h-48 w-full font-mono text-xs leading-5"><%= @import_json %></textarea>
              <button type="submit" class="btn btn-sm rounded-2xl border-0 bg-[#2f4350] text-white shadow-none hover:bg-[#24343e]">Apply Import</button>
            </.form>
          </div>

          <div class="rounded-[28px] border border-white/80 bg-white/82 p-5 shadow-[0_24px_70px_rgba(60,47,31,0.08)] backdrop-blur-xl">
            <p class="text-[0.68rem] uppercase tracking-[0.24em] text-[#7b6d5d]">Background</p>
            <h3 class="text-xl font-black tracking-tight text-[#26333b]">SVG / Image</h3>

            <.form for={%{}} as={:background} phx-submit="save_background" class="mt-4 space-y-3">
              <select name="background[kind]" class="select select-bordered w-full">
                <option value="none" selected={@background_kind == "none"}>None</option>
                <option value="svg" selected={@background_kind == "svg"}>Inline SVG / SVG data</option>
                <option value="image" selected={@background_kind == "image"}>Image URL / data URL</option>
              </select>
              <textarea name="background[value]" class="textarea textarea-bordered h-36 w-full font-mono text-xs leading-5"><%= @background_value %></textarea>
              <button type="submit" class="btn btn-sm rounded-2xl border-0 bg-[#2f4350] text-white shadow-none hover:bg-[#24343e]">Update Background</button>
            </.form>
          </div>

          <div class="rounded-[28px] border border-white/80 bg-white/82 p-5 shadow-[0_24px_70px_rgba(60,47,31,0.08)] backdrop-blur-xl">
            <p class="text-[0.68rem] uppercase tracking-[0.24em] text-[#7b6d5d]">Tournament Teams</p>
            <h3 class="text-xl font-black tracking-tight text-[#26333b]">Assignments / Attributions</h3>

            <div class="mt-4 space-y-2">
              <%= for assignment <- @map_payload["team_assignments"] || [] do %>
                <div class="flex items-center justify-between gap-3 rounded-2xl bg-[#f6f2ea] px-3 py-3 text-sm">
                  <div>
                    <p class="font-semibold text-[#26333b]">{assignment["team_name"]}</p>
                    <p class="text-xs uppercase tracking-[0.16em] text-[#7b6d5d]">{assignment["tournament_name"]} · {assignment["group_id"]}</p>
                  </div>
                  <button
                    type="button"
                    phx-click="remove_team_assignment"
                    phx-value-group_id={assignment["group_id"]}
                    phx-value-tournament_id={assignment["tournament_id"]}
                    class="btn btn-xs rounded-full border-0 bg-[#f5dde1] text-[#8a3240] shadow-none hover:bg-[#efced5]"
                  >
                    Remove
                  </button>
                </div>
              <% end %>

              <%= if Enum.empty?(@map_payload["team_assignments"] || []) do %>
                <p class="rounded-2xl bg-[#f6f2ea] px-3 py-3 text-sm text-[#5a6871]">No tournament team labels yet / Aucune etiquette d'equipe pour le moment.</p>
              <% end %>
            </div>

            <.form for={%{}} as={:team_assignment} phx-submit="assign_team" class="mt-4 space-y-3">
              <select name="team_assignment[group_id]" class="select select-bordered w-full">
                <%= for group <- @map_payload["groups"] || [] do %>
                  <option value={group["id"]} selected={@team_assignment_form["group_id"] == group["id"]}>{group["name"]}</option>
                <% end %>
              </select>
              <select name="team_assignment[tournament_id]" class="select select-bordered w-full">
                <%= for tournament <- @tournaments do %>
                  <option value={tournament.id} selected={to_string(@team_assignment_form["tournament_id"]) == to_string(tournament.id)}>{tournament.name}</option>
                <% end %>
              </select>
              <input name="team_assignment[team_name]" value={@team_assignment_form["team_name"]} class="input input-bordered w-full" placeholder="Team name" />
              <input name="team_assignment[color]" value={@team_assignment_form["color"]} class="input input-bordered w-full" placeholder="#2563eb" />
              <button type="submit" class="btn btn-sm rounded-2xl border-0 bg-[#2f4350] text-white shadow-none hover:bg-[#24343e]">Save Team Label</button>
            </.form>
          </div>

          <div class="rounded-[28px] border border-white/80 bg-white/82 p-5 shadow-[0_24px_70px_rgba(60,47,31,0.08)] backdrop-blur-xl">
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
    first_group = payload["groups"] |> List.first()
    first_tournament = List.first(tournaments)

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
