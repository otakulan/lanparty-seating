defmodule LanpartyseatingWeb.Settings.BadgesLive do
  @moduledoc """
  Settings page for badge management.
  Supports CSV import, paginated listing with search, and per-badge admin/ban toggles.
  Requires full user authentication (not badge auth).
  """
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.BadgesLogic
  alias LanpartyseatingWeb.Components.SettingsNav

  @per_page 50

  # ============================================================================
  # Mount & Handle Params
  # ============================================================================

  def mount(_params, _session, socket) do
    socket =
      socket
      |> allow_upload(:csv_file,
        accept: ~w(.csv),
        max_entries: 1,
        max_file_size: 50_000_000
      )
      |> assign(:upload_error, nil)
      |> assign(:import_result, nil)
      |> assign(:csv_preview, nil)
      |> assign(:show_import_modal, false)
      |> assign(:importing, false)
      |> assign(:delete_confirm_badge, nil)
      |> assign(:show_add_badge_modal, false)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    # Redirect badge-auth users - they don't have access to badge management
    if socket.assigns.is_user_auth do
      page = parse_page(params["page"])
      search = params["search"] || ""

      {:noreply, load_data(socket, page, search)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Full admin access required")
       |> push_navigate(to: ~p"/settings/seating", replace: true)}
    end
  end

  defp parse_page(nil), do: 1
  defp parse_page(page) when is_integer(page), do: page

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {num, _} when num >= 1 -> num
      _ -> 1
    end
  end

  defp load_data(socket, page, search) do
    search_term = if search == "", do: nil, else: search
    badges = BadgesLogic.list_badges(page: page, per_page: @per_page, search: search_term)
    total_count = BadgesLogic.count_badges(search_term)
    total_pages = max(1, ceil(total_count / @per_page))

    socket
    |> assign(:badges, badges)
    |> assign(:page, page)
    |> assign(:search, search)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
    |> assign(:per_page, @per_page)
  end

  # ============================================================================
  # Event Handlers - Search & Pagination
  # ============================================================================

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, push_patch(socket, to: ~p"/settings/badges?#{%{search: search, page: 1}}")}
  end

  def handle_event("prev_page", _params, socket) do
    new_page = max(1, socket.assigns.page - 1)
    {:noreply, push_patch(socket, to: ~p"/settings/badges?#{%{search: socket.assigns.search, page: new_page}}")}
  end

  def handle_event("next_page", _params, socket) do
    new_page = min(socket.assigns.total_pages, socket.assigns.page + 1)
    {:noreply, push_patch(socket, to: ~p"/settings/badges?#{%{search: socket.assigns.search, page: new_page}}")}
  end

  def handle_event("goto_page", %{"page" => page_str}, socket) do
    case Integer.parse(to_string(page_str)) do
      {page, _} when page >= 1 and page <= socket.assigns.total_pages ->
        {:noreply, push_patch(socket, to: ~p"/settings/badges?#{%{search: socket.assigns.search, page: page}}")}

      _ ->
        {:noreply, socket}
    end
  end

  # ============================================================================
  # Event Handlers - Badge Actions
  # ============================================================================

  def handle_event("toggle_admin", %{"id" => id}, socket) do
    badge = BadgesLogic.get_badge!(id)

    case BadgesLogic.update_badge(badge, %{is_admin: !badge.is_admin}) do
      {:ok, _} ->
        {:noreply, load_data(socket, socket.assigns.page, socket.assigns.search)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update badge.")}
    end
  end

  def handle_event("toggle_ban", %{"id" => id}, socket) do
    badge = BadgesLogic.get_badge!(id)

    case BadgesLogic.update_badge(badge, %{is_banned: !badge.is_banned}) do
      {:ok, _} ->
        {:noreply, load_data(socket, socket.assigns.page, socket.assigns.search)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update badge.")}
    end
  end

  def handle_event("save_label", %{"badge_id" => id, "label" => label}, socket) do
    badge = BadgesLogic.get_badge!(id)
    label = if label == "", do: nil, else: label

    case BadgesLogic.update_badge(badge, %{label: label}) do
      {:ok, _} ->
        {:noreply, load_data(socket, socket.assigns.page, socket.assigns.search)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update badge label.")}
    end
  end

  def handle_event("request_delete", %{"id" => id}, socket) do
    badge = BadgesLogic.get_badge!(id)
    {:noreply, assign(socket, :delete_confirm_badge, badge)}
  end

  def handle_event("confirm_delete", _params, socket) do
    badge = socket.assigns.delete_confirm_badge

    case BadgesLogic.delete_badge(badge) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:delete_confirm_badge, nil)
         |> load_data(socket.assigns.page, socket.assigns.search)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:delete_confirm_badge, nil)
         |> put_flash(:error, "Failed to delete badge.")}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_confirm_badge, nil)}
  end

  # ============================================================================
  # Event Handlers - Add Badge
  # ============================================================================

  def handle_event("show_add_badge_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_badge_modal, true)}
  end

  def handle_event("cancel_add_badge", _params, socket) do
    {:noreply, assign(socket, :show_add_badge_modal, false)}
  end

  def handle_event("create_badge", %{"uid" => uid, "serial_key" => serial_key}, socket) do
    case BadgesLogic.create_badge(%{uid: uid, serial_key: serial_key}) do
      {:ok, _badge} ->
        {:noreply,
         socket
         |> assign(:show_add_badge_modal, false)
         |> put_flash(:info, "Badge created successfully.")
         |> load_data(socket.assigns.page, socket.assigns.search)}

      {:error, changeset} ->
        error_msg = BadgesLogic.format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to create badge: #{error_msg}")}
    end
  end

  # ============================================================================
  # Event Handlers - CSV Upload
  # ============================================================================

  def handle_event("open_import_modal", _params, socket) do
    {:noreply, assign(socket, :show_import_modal, true)}
  end

  def handle_event("close_import_modal", _params, socket) do
    # Clean up temp file if exists
    case socket.assigns.csv_preview do
      %{temp_path: temp_path} -> File.rm(temp_path)
      _ -> :ok
    end

    {:noreply,
     socket
     |> assign(:show_import_modal, false)
     |> assign(:csv_preview, nil)
     |> assign(:upload_error, nil)}
  end

  def handle_event("validate_upload", _params, socket) do
    socket =
      socket
      |> assign(:upload_error, nil)
      |> assign(:csv_preview, nil)

    {:noreply, socket}
  end

  def handle_event("preview_csv", _params, socket) do
    case uploaded_entries(socket, :csv_file) do
      {[entry], []} ->
        # Consume the upload to get file path for preview
        result =
          consume_uploaded_entry(socket, entry, fn %{path: path} ->
            case BadgesLogic.validate_csv(path) do
              {:ok, preview} ->
                # Copy file to temp location so we can use it later for import
                temp_path = Path.join(System.tmp_dir!(), "badge_import_#{:rand.uniform(1_000_000)}.csv")
                File.cp!(path, temp_path)
                {:ok, {:preview, preview, temp_path}}

              {:error, reason} ->
                {:ok, {:error, reason}}
            end
          end)

        case result do
          {:preview, preview, temp_path} ->
            {:noreply,
             socket
             |> assign(:csv_preview, Map.put(preview, :temp_path, temp_path))
             |> assign(:upload_error, nil)}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:upload_error, reason)
             |> assign(:csv_preview, nil)}
        end

      {[], [_error | _]} ->
        {:noreply, assign(socket, :upload_error, "Invalid file. Please select a CSV file.")}

      _ ->
        {:noreply, assign(socket, :upload_error, "Please select a CSV file first.")}
    end
  end

  def handle_event("confirm_import", _params, socket) do
    case socket.assigns.csv_preview do
      %{temp_path: _temp_path} ->
        # Set importing state and trigger async import
        # This allows the UI to update with spinner before the import runs
        send(self(), :do_import)

        {:noreply, assign(socket, :importing, true)}

      _ ->
        {:noreply, assign(socket, :upload_error, "No file to import.")}
    end
  end

  def handle_event("cancel_import", _params, socket) do
    # Clean up temp file if exists
    case socket.assigns.csv_preview do
      %{temp_path: temp_path} -> File.rm(temp_path)
      _ -> :ok
    end

    {:noreply,
     socket
     |> assign(:csv_preview, nil)
     |> assign(:upload_error, nil)
     |> assign(:show_import_modal, false)}
  end

  # ============================================================================
  # Handle Info (async operations)
  # ============================================================================

  def handle_info(:do_import, socket) do
    case socket.assigns.csv_preview do
      %{temp_path: temp_path} ->
        case BadgesLogic.import_from_csv(temp_path) do
          {:ok, count} ->
            # Clean up temp file
            File.rm(temp_path)

            {:noreply,
             socket
             |> assign(:csv_preview, nil)
             |> assign(:import_result, {:ok, count})
             |> assign(:show_import_modal, false)
             |> assign(:importing, false)
             |> load_data(1, "")
             |> put_flash(:info, "Successfully imported #{count} badges.")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:upload_error, "Import failed: #{inspect(reason)}")
             |> assign(:csv_preview, nil)
             |> assign(:importing, false)}
        end

      _ ->
        {:noreply,
         socket
         |> assign(:upload_error, "No file to import.")
         |> assign(:importing, false)}
    end
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
          <span class="text-lg font-bold">Badges</span>
        </div>

        <%!-- Main content area --%>
        <div class="p-4 lg:p-6">
          <.badges_content {assigns} />
        </div>
      </div>

      <div class="drawer-side z-40">
        <label for="settings-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <SettingsNav.settings_nav current_page={:badges} is_user_auth={@is_user_auth} />
      </div>

      <%!-- CSV Import Modal --%>
      <.csv_import_modal {assigns} />

      <%!-- Delete Confirmation Modal --%>
      <.delete_confirm_modal badge={@delete_confirm_badge} />

      <%!-- Add Badge Modal --%>
      <.add_badge_modal show={@show_add_badge_modal} />
    </div>
    """
  end

  defp badges_content(assigns) do
    ~H"""
    <div class="max-w-6xl">
      <.page_header title="Badges" subtitle="Manage attendee badges. Import from CSV or configure admin access.">
        <:trailing>
          <span class="text-base-content/60">{@total_count} total badges</span>
        </:trailing>
      </.page_header>

      <%!-- Search + Import Button Row --%>
      <div class="flex justify-between items-center mb-6 gap-4">
        <form phx-change="search" class="flex-1 max-w-md flex gap-2 items-center">
          <input
            type="text"
            name="search"
            value={@search}
            placeholder="Search by UID or serial key..."
            class="input input-bordered w-full"
            phx-debounce="300"
          />
          <%= if @search != "" do %>
            <.link navigate={~p"/settings/badges"} class="btn btn-ghost btn-sm">
              Clear
            </.link>
          <% end %>
        </form>

        <div class="flex gap-2">
          <button
            type="button"
            class="btn btn-primary"
            phx-click="show_add_badge_modal"
          >
            <Icons.plus class="w-4 h-4" /> Add Badge
          </button>
          <button
            type="button"
            class="btn btn-primary"
            phx-click="open_import_modal"
          >
            <Icons.arrow_up_tray class="w-4 h-4" /> Import CSV
          </button>
        </div>
      </div>

      <%!-- Badges Table --%>
      <%= if Enum.empty?(@badges) do %>
        <div class="rounded-box border border-base-content/5 bg-base-100 p-8 text-center">
          <p class="text-base-content/60">
            <%= if @search != "" do %>
              No badges found matching "{@search}".
            <% else %>
              No badges yet. Import a CSV to get started.
            <% end %>
          </p>
        </div>
      <% else %>
        <div class="rounded-box border border-base-content/5 bg-base-100 overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr class="border-b border-base-content/10">
                <th class="text-base-content w-[20%]">UID</th>
                <th class="text-base-content w-[12%]">Serial Key</th>
                <th class="text-base-content">Label</th>
                <th class="text-base-content w-[25%]">Status</th>
                <th class="w-[8%]"></th>
              </tr>
            </thead>
            <tbody>
              <%= for badge <- @badges do %>
                <tr class="group hover:bg-base-200 border-b border-base-content/5">
                  <td class="font-mono text-sm">{badge.uid}</td>
                  <td class="font-mono">{badge.serial_key}</td>
                  <td>
                    <.inline_label_editor badge={badge} />
                  </td>
                  <td class="space-x-1">
                    <%= if badge.is_admin do %>
                      <span class="badge badge-primary badge-sm">Admin</span>
                    <% end %>
                    <%= if badge.is_banned do %>
                      <span class="badge badge-error badge-sm">Banned</span>
                    <% end %>
                    <%= if !badge.is_admin && !badge.is_banned do %>
                      <span class="badge badge-ghost badge-sm">Normal</span>
                    <% end %>
                  </td>
                  <td class="text-right">
                    <button
                      class="btn btn-ghost btn-xs"
                      popovertarget={"badge-menu-#{badge.id}"}
                      style={"anchor-name: --badge-anchor-#{badge.id}"}
                    >
                      <Icons.ellipsis_vertical class="w-4 h-4" />
                    </button>
                    <ul
                      id={"badge-menu-#{badge.id}"}
                      popover="auto"
                      class="dropdown menu rounded-box bg-base-200 shadow-sm"
                      style={"position-anchor: --badge-anchor-#{badge.id}; position-area: bottom span-left;"}
                    >
                      <li>
                        <button phx-click="toggle_admin" phx-value-id={badge.id} class="justify-end" onclick="this.closest('[popover]').hidePopover()">
                          {if badge.is_admin, do: "Revoke Admin", else: "Make Admin"}
                        </button>
                      </li>
                      <li>
                        <button phx-click="toggle_ban" phx-value-id={badge.id} class="justify-end" onclick="this.closest('[popover]').hidePopover()">
                          {if badge.is_banned, do: "Unban", else: "Ban"}
                        </button>
                      </li>
                      <li>
                        <button phx-click="request_delete" phx-value-id={badge.id} class="justify-end text-error" onclick="this.closest('[popover]').hidePopover()">
                          Delete
                        </button>
                      </li>
                    </ul>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Smart Pagination --%>
        <.smart_pagination page={@page} total_pages={@total_pages} total_count={@total_count} per_page={@per_page} search={@search} />
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # Components
  # ============================================================================

  defp csv_import_modal(assigns) do
    ~H"""
    <dialog class={["modal", @show_import_modal && "modal-open"]}>
      <div class="modal-box max-w-2xl">
        <button
          type="button"
          class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
          phx-click="close_import_modal"
        >
          ✕
        </button>
        <h3 class="text-xl font-bold mb-4">Import Badges from CSV</h3>

        <%= if @importing do %>
          <%!-- Importing State --%>
          <div class="flex flex-col items-center justify-center py-12">
            <span class="loading loading-spinner loading-lg text-primary"></span>
            <p class="mt-4 text-base-content/70">Importing badges...</p>
            <p class="text-sm text-base-content/50 mt-1">This may take a moment for large files.</p>
          </div>
        <% else %>
          <div class="alert alert-warning mb-4">
            <Icons.exclamation_triangle class="w-5 h-5" />
            <div>
              <p class="font-semibold">Warning: Import will replace ALL existing badges</p>
              <p class="text-sm">Admin status and ban flags will be reset. Make note of admin badges before importing.</p>
            </div>
          </div>

          <%= if @csv_preview do %>
            <%!-- Preview Mode --%>
            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <div>
                  <p class="font-semibold">Ready to import</p>
                  <p class="text-sm text-base-content/70">
                    {if @csv_preview.truncated, do: "#{@csv_preview.row_count}+ rows", else: "#{@csv_preview.row_count} rows"} found in CSV
                  </p>
                </div>
              </div>

              <div class="overflow-x-auto rounded-box border border-base-content/10">
                <table class="table table-sm table-fixed w-full">
                  <thead>
                    <tr>
                      <th>Serial Key</th>
                      <th>UID</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for row <- @csv_preview.sample_rows do %>
                      <tr>
                        <td class="font-mono">{row.serial_key}</td>
                        <td class="font-mono">{row.uid}</td>
                      </tr>
                    <% end %>
                    <%= if length(@csv_preview.sample_rows) < @csv_preview.row_count do %>
                      <tr>
                        <td colspan="2" class="text-center text-base-content/50">
                          ... and {@csv_preview.row_count - length(@csv_preview.sample_rows)} more rows
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <div class="flex gap-2">
                <button type="button" class="btn btn-error" phx-click="confirm_import">
                  <Icons.exclamation_triangle class="w-4 h-4" /> Replace All & Import
                </button>
                <button type="button" class="btn btn-ghost" phx-click="close_import_modal">
                  Cancel
                </button>
              </div>
            </div>
          <% else %>
            <%!-- Upload Mode --%>
            <form phx-change="validate_upload" phx-submit="preview_csv" class="space-y-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">CSV File (columns: serial_key, uid)</span>
                </label>
                <.live_file_input upload={@uploads.csv_file} class="file-input file-input-bordered w-full" />
                <label class="label">
                  <span class="label-text-alt">Maximum file size: 50MB</span>
                </label>
              </div>

              <%= if @upload_error do %>
                <div class="alert alert-error">
                  <Icons.x_circle class="w-5 h-5" />
                  <span>{@upload_error}</span>
                </div>
              <% end %>

              <%= for entry <- @uploads.csv_file.entries do %>
                <div class="flex items-center gap-2 text-sm">
                  <Icons.arrow_up_tray class="w-4 h-4" />
                  <span>{entry.client_name}</span>
                  <span class="text-base-content/50">({format_file_size(entry.client_size)})</span>
                </div>
              <% end %>

              <button
                type="submit"
                class="btn btn-primary"
                disabled={@uploads.csv_file.entries == []}
              >
                Preview Import
              </button>
            </form>
          <% end %>
        <% end %>
      </div>
      <div class="modal-backdrop" phx-click="close_import_modal">
        <button type="button">close</button>
      </div>
    </dialog>
    """
  end

  defp delete_confirm_modal(assigns) do
    ~H"""
    <dialog class={["modal", @badge && "modal-open"]}>
      <div class="modal-box">
        <h3 class="font-bold text-lg text-error">
          Delete Badge
        </h3>
        <div class="py-4">
          <p class="mb-4">
            This action cannot be undone. The following badge will be permanently deleted:
          </p>
          <%= if @badge do %>
            <div class="bg-base-200 rounded-lg p-3 space-y-1">
              <p><span class="font-semibold">UID:</span> <span class="font-mono">{@badge.uid}</span></p>
              <%= if @badge.label && @badge.label != "" do %>
                <p><span class="font-semibold">Label:</span> {@badge.label}</p>
              <% end %>
              <div class="flex gap-1 mt-2">
                <%= if @badge.is_admin do %>
                  <span class="badge badge-primary badge-sm">Admin</span>
                <% end %>
                <%= if @badge.is_banned do %>
                  <span class="badge badge-error badge-sm">Banned</span>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
        <div class="modal-action">
          <button class="btn" phx-click="cancel_delete">
            Cancel
          </button>
          <button class="btn btn-error" phx-click="confirm_delete">
            Delete Badge
          </button>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop">
        <button phx-click="cancel_delete">close</button>
      </form>
    </dialog>
    """
  end

  defp add_badge_modal(assigns) do
    ~H"""
    <dialog class={["modal", @show && "modal-open"]}>
      <div class="modal-box">
        <h3 class="font-bold text-lg">Add Badge</h3>
        <form phx-submit="create_badge" class="py-4 space-y-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text">UID</span>
            </label>
            <input
              type="text"
              name="uid"
              class="input input-bordered"
              placeholder="E0040153255CEF2C"
              required
            />
          </div>
          <div class="form-control">
            <label class="label">
              <span class="label-text">Serial Key</span>
            </label>
            <input
              type="text"
              name="serial_key"
              class="input input-bordered"
              placeholder="386687"
              required
            />
          </div>
          <div class="modal-action">
            <button type="button" class="btn" phx-click="cancel_add_badge">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">
              Add Badge
            </button>
          </div>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop">
        <button phx-click="cancel_add_badge">close</button>
      </form>
    </dialog>
    """
  end

  defp smart_pagination(assigns) do
    # Build page numbers list with ellipsis
    # Always show: page 1, last page, and 2 pages on either side of current
    # Example: current=11, total=1000 → [1, ..., 9, 10, 11, 12, 13, ..., 1000]
    current = assigns.page
    total = assigns.total_pages

    pages =
      if total <= 7 do
        # Show all pages if 7 or fewer
        Enum.to_list(1..total)
      else
        # Calculate middle window (2 pages on each side of current)
        middle_start = max(2, current - 2)
        middle_end = min(total - 1, current + 2)

        # Build the page list with ellipsis markers
        left = [1]
        left_ellipsis = if middle_start > 2, do: [:ellipsis_left], else: []
        middle = Enum.to_list(middle_start..middle_end)
        right_ellipsis = if middle_end < total - 1, do: [:ellipsis_right], else: []
        right = [total]

        (left ++ left_ellipsis ++ middle ++ right_ellipsis ++ right)
        |> Enum.uniq()
      end

    assigns = assign(assigns, :pages, pages)

    ~H"""
    <div class="flex flex-col sm:flex-row items-center justify-between gap-4 mt-4">
      <p class="text-sm text-base-content/70">
        Showing {(@page - 1) * @per_page + 1}-{min(@page * @per_page, @total_count)} of {@total_count}
        <%= if @search != "" do %>
          <span>(filtered)</span>
        <% end %>
      </p>

      <div class="join">
        <button
          type="button"
          class="join-item btn btn-sm"
          phx-click="prev_page"
          disabled={@page <= 1}
        >
          «
        </button>

        <%= for p <- @pages do %>
          <%= if p in [:ellipsis_left, :ellipsis_right] do %>
            <button type="button" class="join-item btn btn-sm btn-disabled">...</button>
          <% else %>
            <button
              type="button"
              class={["join-item btn btn-sm", if(p == @page, do: "btn-active", else: "")]}
              phx-click="goto_page"
              phx-value-page={p}
            >
              {p}
            </button>
          <% end %>
        <% end %>

        <button
          type="button"
          class="join-item btn btn-sm"
          phx-click="next_page"
          disabled={@page >= @total_pages}
        >
          »
        </button>

        <form phx-submit="goto_page" class="contents">
          <input
            type="number"
            name="page"
            class="join-item input input-sm input-bordered w-16 text-center"
            placeholder="#"
            min="1"
            max={@total_pages}
          />
        </form>
      </div>
    </div>
    """
  end

  defp inline_label_editor(assigns) do
    ~H"""
    <form phx-submit="save_label" class="flex gap-1 items-center">
      <input type="hidden" name="badge_id" value={@badge.id} />
      <input
        type="text"
        name="label"
        value={@badge.label || ""}
        placeholder={@badge.serial_key}
        class="input input-xs input-bordered w-32 peer"
      />
      <button
        type="submit"
        class="btn btn-xs btn-ghost opacity-0 group-hover:opacity-100 peer-focus:opacity-100 transition-opacity"
        title="Save label"
      >
        <Icons.check class="w-3 h-3" />
      </button>
    </form>
    """
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_file_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_file_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
