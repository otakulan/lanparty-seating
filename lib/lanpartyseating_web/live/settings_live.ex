defmodule LanpartyseatingWeb.SettingsLive do
  @moduledoc """
  Unified settings page with sidebar navigation.
  Handles seating configuration, user management, badge management, and scanners.
  """
  use LanpartyseatingWeb, :live_view
  require Logger
  import Ecto.Query
  alias Lanpartyseating.Repo
  alias Lanpartyseating.PubSub
  alias Lanpartyseating.Accounts
  alias Lanpartyseating.ScannerLogic

  # ============================================================================
  # Mount & Handle Params
  # ============================================================================

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(_params, _uri, %{assigns: %{live_action: :index}} = socket) do
    # Redirect /settings to /settings/seating
    {:noreply, push_navigate(socket, to: ~p"/settings/seating", replace: true)}
  end

  def handle_params(_params, _uri, %{assigns: %{live_action: action}} = socket)
      when action in [:users, :badges] do
    # User-only sections - redirect badge-auth users
    if socket.assigns.is_user_auth do
      {:noreply, load_section_data(socket)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Full admin access required")
       |> push_navigate(to: ~p"/settings/seating", replace: true)}
    end
  end

  def handle_params(_params, _uri, socket) do
    # Public sections (seating, scanners)
    {:noreply, load_section_data(socket)}
  end

  defp load_section_data(%{assigns: %{live_action: :seating}} = socket) do
    {:ok, settings} = Lanpartyseating.SettingsLogic.get_settings()
    layout = Lanpartyseating.StationLogic.get_station_layout()
    {columns, rows} = grid_dimensions(layout)
    station_count = Repo.one(from(s in Lanpartyseating.Station, select: count("*")))
    layout = resize_grid(layout, columns, rows, station_count)
    {columns, rows} = grid_dimensions(layout)

    socket
    |> assign(:columns, columns)
    |> assign(:rows, rows)
    |> assign(:station_count, station_count)
    |> assign(:colpad, settings.column_padding)
    |> assign(:rowpad, settings.row_padding)
    |> socket_assign_grid(layout)
  end

  defp load_section_data(%{assigns: %{live_action: :users}} = socket) do
    socket
    |> assign(:users, Accounts.list_users())
    |> assign(:show_create_form, false)
    |> assign(:form, to_form(%{"name" => "", "email" => "", "password" => ""}, as: "user"))
    |> assign(:form_error, nil)
  end

  defp load_section_data(%{assigns: %{live_action: :badges}} = socket) do
    socket
    |> assign(:badges, Accounts.list_admin_badges())
    |> assign(:show_create_form, false)
    |> assign(:form, to_form(%{"badge_number" => "", "label" => "", "enabled" => "true"}, as: "badge"))
    |> assign(:form_error, nil)
  end

  defp load_section_data(%{assigns: %{live_action: :scanners}} = socket) do
    wifi_config = ScannerLogic.get_wifi_config()
    scanners = ScannerLogic.list_scanners()
    can_edit_wifi = ScannerLogic.can_edit_wifi_config?()

    {ssid, password} =
      case wifi_config do
        {:ok, config} -> {config.ssid, config.password}
        {:error, :not_configured} -> {"", ""}
      end

    socket
    |> assign(:scanners, scanners)
    |> assign(:wifi_configured, match?({:ok, _}, wifi_config))
    |> assign(:can_edit_wifi, can_edit_wifi)
    |> assign(:wifi_form, to_form(%{"ssid" => ssid, "password" => password}, as: "wifi"))
    |> assign(:wifi_form_error, nil)
    |> assign(:show_create_form, false)
    |> assign(:scanner_form, to_form(%{"name" => ""}, as: "scanner"))
    |> assign(:scanner_form_error, nil)
    |> assign(:provisioning_scanner, nil)
    |> assign(:ble_status, nil)
    |> assign(:ble_connected, false)
    |> assign(:ble_device_name, nil)
    |> assign(:bluetooth_status, :supported)
  end

  # ============================================================================
  # Seating Configuration - Grid Helper Functions
  # ============================================================================

  defp minmax_row(grid, y_in) do
    grid
    |> Enum.reject(fn {{_x, y}, _} -> y != y_in end)
    |> Enum.map(fn {{x, _}, _} -> x end)
    |> Enum.min_max()
  end

  defp minmax_column(grid, x_in) do
    grid
    |> Enum.reject(fn {{x, _y}, _} -> x != x_in end)
    |> Enum.map(fn {{_, y}, _} -> y end)
    |> Enum.min_max()
  end

  defp reverse_rows(grid, rem) do
    grid
    |> Enum.map(fn {{x, y}, num} ->
      if rem(y, 2) == rem do
        {min_x, max_x} = minmax_row(grid, y)
        {{max_x - x + min_x, y}, num}
      else
        {{x, y}, num}
      end
    end)
    |> Enum.into(%{})
  end

  defp reverse_even_rows(grid), do: reverse_rows(grid, 0)
  defp reverse_odd_rows(grid), do: reverse_rows(grid, 1)

  defp reverse_columns(grid, rem) do
    grid
    |> Enum.map(fn {{x, y}, num} ->
      if rem(x, 2) == rem do
        {min_y, max_y} = minmax_column(grid, x)
        {{x, max_y - y + min_y}, num}
      else
        {{x, y}, num}
      end
    end)
    |> Enum.into(%{})
  end

  defp reverse_even_columns(grid), do: reverse_columns(grid, 0)
  defp reverse_odd_columns(grid), do: reverse_columns(grid, 1)

  defp transpose(grid) do
    grid
    |> Enum.map(fn {{x, y}, num} -> {{y, x}, num} end)
    |> Enum.into(%{})
  end

  defp grid_dimensions(grid) do
    {max_x, max_y} =
      Map.keys(grid)
      |> Enum.reduce({0, 0}, fn {x, y}, {max_x, max_y} -> {max(x, max_x), max(y, max_y)} end)

    {max_x + 1, max_y + 1}
  end

  defp socket_assign_grid(socket, grid) do
    {columns, rows} = grid_dimensions(grid)

    socket
    |> assign(:grid_width, columns)
    |> assign(:grid_height, rows)
    |> assign(:grid, grid)
  end

  defp add_stations_to_grid(grid, column_major?, columns, rows, first_num, count) do
    order =
      if column_major? do
        for c <- 0..(columns - 1), r <- 0..(rows - 1), do: {c, r}
      else
        for r <- 0..(rows - 1), c <- 0..(columns - 1), do: {c, r}
      end

    order
    |> Stream.reject(fn pos -> Map.has_key?(grid, pos) end)
    |> Enum.take(count)
    |> Enum.with_index()
    |> Enum.map(fn {pos, index} -> {pos, index + first_num} end)
    |> Enum.into(grid)
  end

  defp truncate_grid(grid, max) do
    grid |> Enum.reject(fn {_, num} -> num > max end) |> Enum.into(%{})
  end

  defp resize_grid(grid, columns, rows, count) do
    if map_size(grid) > count do
      truncate_grid(grid, count)
    else
      add_stations_to_grid(grid, true, columns, rows, map_size(grid) + 1, count - map_size(grid))
    end
  end

  # ============================================================================
  # Event Handlers - Seating Configuration
  # ============================================================================

  def handle_event("change_dimensions", %{"rows" => rows, "columns" => columns}, socket) do
    {:noreply,
     socket
     |> assign(:rows, String.to_integer(rows))
     |> assign(:columns, String.to_integer(columns))}
  end

  def handle_event("change_padding", %{"rowpad" => rowpad, "colpad" => colpad}, socket) do
    {:noreply,
     socket
     |> assign(:rowpad, String.to_integer(rowpad))
     |> assign(:colpad, String.to_integer(colpad))}
  end

  def handle_event("horizontal_mirror_even", _params, socket) do
    {:noreply, socket_assign_grid(socket, reverse_even_rows(socket.assigns.grid))}
  end

  def handle_event("horizontal_mirror_odd", _params, socket) do
    {:noreply, socket_assign_grid(socket, reverse_odd_rows(socket.assigns.grid))}
  end

  def handle_event("vertical_mirror_even", _params, socket) do
    {:noreply, socket_assign_grid(socket, reverse_even_columns(socket.assigns.grid))}
  end

  def handle_event("vertical_mirror_odd", _params, socket) do
    {:noreply, socket_assign_grid(socket, reverse_odd_columns(socket.assigns.grid))}
  end

  def handle_event("diagonal_mirror", _params, socket) do
    grid = transpose(socket.assigns.grid)
    {columns, rows} = grid_dimensions(grid)

    {:noreply,
     socket
     |> assign(:columns, columns)
     |> assign(:rows, rows)
     |> socket_assign_grid(grid)}
  end

  def handle_event("reset_grid_column_major", _params, socket) do
    grid = add_stations_to_grid(%{}, true, socket.assigns.columns, socket.assigns.rows, 1, socket.assigns.station_count)
    {:noreply, socket_assign_grid(socket, grid)}
  end

  def handle_event("reset_grid_row_major", _params, socket) do
    grid = add_stations_to_grid(%{}, false, socket.assigns.columns, socket.assigns.rows, 1, socket.assigns.station_count)
    {:noreply, socket_assign_grid(socket, grid)}
  end

  def handle_event("save", _params, socket) do
    s = socket.assigns

    save_stations = Lanpartyseating.StationLogic.save_stations(s.grid)
    save_settings = Lanpartyseating.SettingsLogic.settings_db_changes(s.rowpad, s.colpad)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.append(save_settings)
      |> Ecto.Multi.append(save_stations)

    socket =
      try do
        case Repo.transaction(multi) do
          {:ok, _result} ->
            {columns, rows} = grid_dimensions(s.grid)
            publish_station_update()

            socket
            |> assign(:columns, columns)
            |> assign(:rows, rows)
            |> put_flash(:info, "Saved successfully")

          {:error, failed_operation, failed_value, changes_so_far} ->
            Logger.error("Transaction error")
            Logger.error("operation: #{failed_operation}")
            Logger.error("failed value: #{failed_value}")
            Logger.error("#{inspect(changes_so_far)}")

            socket
            |> put_flash(:error, "Transaction error\noperation: #{failed_operation}\nfailed value: #{failed_value}\n#{inspect(changes_so_far)}")
        end
      rescue
        e ->
          Logger.error("Postgres exception trying to commit transaction: #{inspect(e)}")
          socket |> put_flash(:error, "Postgres exception trying to commit transaction:\n#{inspect(e)}")
      end

    {:noreply, socket}
  end

  def handle_event("move", params, socket) do
    grid = socket.assigns.grid
    %{"from" => %{"x" => x1, "y" => y1}, "to" => %{"x" => x2, "y" => y2}} = params
    from_num = Map.get(grid, {x1, y1})
    to_num = Map.get(grid, {x2, y2})

    grid =
      if to_num != nil do
        grid
        |> Map.put({x1, y1}, to_num)
        |> Map.put({x2, y2}, from_num)
      else
        grid
        |> Map.delete({x1, y1})
        |> Map.put({x2, y2}, from_num)
      end

    {:noreply, socket_assign_grid(socket, grid)}
  end

  def handle_event("change_station_count", %{"station_count" => count}, socket) do
    grid = socket.assigns.grid
    count = String.to_integer(count)
    grid = resize_grid(grid, socket.assigns.columns, socket.assigns.rows, count)

    {:noreply,
     socket
     |> assign(:station_count, count)
     |> socket_assign_grid(grid)}
  end

  # ============================================================================
  # Event Handlers - Toggle Create Form (grouped to avoid compiler warning)
  # ============================================================================

  def handle_event("toggle_create_form", _params, %{assigns: %{live_action: :users}} = socket) do
    {:noreply,
     socket
     |> assign(:show_create_form, !socket.assigns.show_create_form)
     |> assign(:form, to_form(%{"name" => "", "email" => "", "password" => ""}, as: "user"))
     |> assign(:form_error, nil)}
  end

  def handle_event("toggle_create_form", _params, %{assigns: %{live_action: :badges}} = socket) do
    {:noreply,
     socket
     |> assign(:show_create_form, !socket.assigns.show_create_form)
     |> assign(:form, to_form(%{"badge_number" => "", "label" => "", "enabled" => "true"}, as: "badge"))
     |> assign(:form_error, nil)}
  end

  def handle_event("toggle_create_form", _params, %{assigns: %{live_action: :scanners}} = socket) do
    {:noreply,
     socket
     |> assign(:show_create_form, !socket.assigns.show_create_form)
     |> assign(:scanner_form, to_form(%{"name" => ""}, as: "scanner"))
     |> assign(:scanner_form_error, nil)}
  end

  # ============================================================================
  # Event Handlers - Users
  # ============================================================================

  def handle_event("create_user", %{"user" => user_params}, socket) do
    case Accounts.create_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(:users, Accounts.list_users())
         |> assign(:show_create_form, false)
         |> assign(:form, to_form(%{"name" => "", "email" => "", "password" => ""}, as: "user"))
         |> assign(:form_error, nil)
         |> put_flash(:info, "User created successfully.")}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)

        {:noreply,
         socket
         |> assign(:form, to_form(user_params, as: "user"))
         |> assign(:form_error, error_msg)}
    end
  end

  def handle_event("delete_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    if user.id == socket.assigns.current_scope.user.id do
      {:noreply, put_flash(socket, :error, "You cannot delete your own account.")}
    else
      case Accounts.delete_user(user) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:users, Accounts.list_users())
           |> put_flash(:info, "User deleted.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete user.")}
      end
    end
  end

  # ============================================================================
  # Event Handlers - Badges
  # ============================================================================

  def handle_event("create_badge", %{"badge" => badge_params}, socket) do
    badge_params = Map.put(badge_params, "enabled", badge_params["enabled"] == "true")

    case Accounts.create_admin_badge(badge_params) do
      {:ok, _badge} ->
        {:noreply,
         socket
         |> assign(:badges, Accounts.list_admin_badges())
         |> assign(:show_create_form, false)
         |> assign(:form, to_form(%{"badge_number" => "", "label" => "", "enabled" => "true"}, as: "badge"))
         |> assign(:form_error, nil)
         |> put_flash(:info, "Admin badge created successfully.")}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)

        {:noreply,
         socket
         |> assign(:form, to_form(badge_params, as: "badge"))
         |> assign(:form_error, error_msg)}
    end
  end

  def handle_event("toggle_badge", %{"id" => id}, socket) do
    badge = Accounts.get_admin_badge!(id)

    case Accounts.update_admin_badge(badge, %{enabled: !badge.enabled}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:badges, Accounts.list_admin_badges())
         |> put_flash(:info, "Badge #{if badge.enabled, do: "disabled", else: "enabled"}.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update badge.")}
    end
  end

  def handle_event("delete_badge", %{"id" => id}, socket) do
    badge = Accounts.get_admin_badge!(id)

    case Accounts.delete_admin_badge(badge) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:badges, Accounts.list_admin_badges())
         |> put_flash(:info, "Badge deleted.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete badge.")}
    end
  end

  # ============================================================================
  # Event Handlers - Scanners
  # ============================================================================

  def handle_event("save_wifi", %{"wifi" => wifi_params}, socket) do
    case ScannerLogic.set_wifi_config(wifi_params) do
      {:ok, _config} ->
        {:noreply,
         socket
         |> assign(:wifi_configured, true)
         |> assign(:wifi_form_error, nil)
         |> put_flash(:info, "WiFi configuration saved.")}

      {:error, :scanners_exist} ->
        {:noreply,
         socket
         |> assign(:wifi_form_error, "Cannot modify WiFi settings while scanners exist. Delete all scanners first.")}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        {:noreply, assign(socket, :wifi_form_error, error_msg)}
    end
  end

  def handle_event("create_scanner", %{"scanner" => scanner_params}, socket) do
    case ScannerLogic.create_scanner(scanner_params) do
      {:ok, %{scanner: _scanner, token: _token}} ->
        {:noreply,
         socket
         |> assign(:scanners, ScannerLogic.list_scanners())
         |> assign(:show_create_form, false)
         |> assign(:scanner_form_error, nil)
         |> put_flash(:info, "Scanner created.")}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        {:noreply, assign(socket, :scanner_form_error, error_msg)}
    end
  end

  def handle_event("revoke_scanner", %{"id" => id}, socket) do
    case ScannerLogic.revoke_scanner(String.to_integer(id)) do
      :ok ->
        {:noreply,
         socket
         |> assign(:scanners, ScannerLogic.list_scanners())
         |> put_flash(:info, "Scanner revoked.")}

      {:error, :already_revoked} ->
        {:noreply, put_flash(socket, :error, "Scanner already revoked.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Scanner not found.")}
    end
  end

  def handle_event("delete_scanner", %{"id" => id}, socket) do
    case ScannerLogic.delete_scanner(String.to_integer(id)) do
      :ok ->
        {:noreply,
         socket
         |> assign(:scanners, ScannerLogic.list_scanners())
         |> assign(:can_edit_wifi, ScannerLogic.can_edit_wifi_config?())
         |> put_flash(:info, "Scanner deleted.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Scanner not found.")}
    end
  end

  def handle_event("start_provisioning", %{"id" => id}, socket) do
    scanner_id = String.to_integer(id)

    case ScannerLogic.get_scanner(scanner_id) do
      {:ok, scanner} ->
        {:noreply,
         socket
         |> assign(:provisioning_scanner, scanner)
         |> assign(:ble_status, nil)
         |> assign(:ble_connected, false)
         |> assign(:ble_device_name, nil)
         |> assign(:api_url_override, "")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Scanner not found.")}
    end
  end

  def handle_event("update_api_url_override", %{"value" => value}, socket) do
    {:noreply, assign(socket, :api_url_override, value)}
  end

  def handle_event("cancel_provisioning", _params, socket) do
    {:noreply,
     socket
     |> assign(:provisioning_scanner, nil)
     |> assign(:ble_status, nil)
     |> assign(:ble_connected, false)
     |> assign(:ble_device_name, nil)}
  end

  def handle_event("ble_connect", _params, socket) do
    {:noreply, push_event(socket, "ble_connect", %{})}
  end

  def handle_event("ble_disconnect", _params, socket) do
    {:noreply, push_event(socket, "ble_disconnect", %{})}
  end

  def handle_event("ble_provision", _params, socket) do
    case ScannerLogic.get_wifi_config() do
      {:ok, wifi_config} ->
        scanner = socket.assigns.provisioning_scanner
        override = socket.assigns[:api_url_override] || ""

        api_url =
          if override != "" do
            override
          else
            LanpartyseatingWeb.Endpoint.url()
          end

        # Regenerate the scanner token for provisioning
        case regenerate_scanner_token(scanner.id) do
          {:ok, token} ->
            {:noreply,
             socket
             |> push_event("ble_provision", %{
               ssid: wifi_config.ssid,
               password: wifi_config.password,
               apiUrl: api_url,
               apiToken: token,
             })}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to generate provisioning token.")}
        end

      {:error, :not_configured} ->
        {:noreply, put_flash(socket, :error, "WiFi not configured. Please configure WiFi settings first.")}
    end
  end

  # Handle BLE events from JavaScript hook
  def handle_event("bluetooth_unsupported", %{"reason" => reason}, socket) do
    {:noreply, assign(socket, :bluetooth_status, String.to_atom(reason))}
  end

  def handle_event("bluetooth_unsupported", _params, socket) do
    # Fallback for old format without reason
    {:noreply, assign(socket, :bluetooth_status, :not_available)}
  end

  def handle_event("ble_status", %{"status" => status, "message" => message}, socket) do
    {:noreply, assign(socket, :ble_status, %{status: status, message: message})}
  end

  def handle_event("ble_connected", %{"deviceName" => device_name}, socket) do
    {:noreply,
     socket
     |> assign(:ble_connected, true)
     |> assign(:ble_device_name, device_name)
     |> assign(:ble_status, %{status: "connected", message: "Connected to #{device_name}"})}
  end

  def handle_event("ble_disconnected", _params, socket) do
    {:noreply,
     socket
     |> assign(:ble_connected, false)
     |> assign(:ble_device_name, nil)
     |> assign(:ble_status, nil)}
  end

  def handle_event("ble_error", %{"message" => message}, socket) do
    {:noreply,
     socket
     |> assign(:ble_status, %{status: "error", message: message})
     |> assign(:ble_connected, false)}
  end

  def handle_event("ble_provisioned", params, socket) do
    scanner = socket.assigns.provisioning_scanner
    ScannerLogic.mark_provisioned(scanner.id)

    warning = Map.get(params, "warning")

    socket =
      socket
      |> assign(:scanners, ScannerLogic.list_scanners())
      |> assign(:provisioning_scanner, nil)
      |> assign(:ble_status, nil)
      |> assign(:ble_connected, false)
      |> assign(:ble_device_name, nil)

    socket =
      if warning do
        put_flash(socket, :info, "Scanner provisioned successfully. #{warning}")
      else
        put_flash(socket, :info, "Scanner provisioned successfully!")
      end

    {:noreply, socket}
  end

  defp regenerate_scanner_token(scanner_id) do
    # Delete and recreate the scanner to get a new token
    # This is a bit heavy-handed, but ensures token security
    with {:ok, scanner} <- ScannerLogic.get_scanner(scanner_id) do
      # Create new token for this scanner
      token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      full_token = "lpss_" <> token
      token_hash = Bcrypt.hash_pwd_salt(token)
      token_prefix = "lpss_" <> String.slice(token, 0, 8)

      scanner
      |> Ecto.Changeset.change(%{token_hash: token_hash, token_prefix: token_prefix})
      |> Repo.update()

      {:ok, full_token}
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp publish_station_update do
    {:ok, stations} = Lanpartyseating.StationLogic.get_all_stations()
    Phoenix.PubSub.broadcast(PubSub, "station_update", {:stations, stations})
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end

  defp section_title(:seating), do: "Seating Configuration"
  defp section_title(:users), do: "Users"
  defp section_title(:badges), do: "Badges"
  defp section_title(:scanners), do: "Scanners"
  defp section_title(_), do: "Settings"

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
          <span class="text-lg font-bold">{section_title(@live_action)}</span>
        </div>

        <%!-- Main content area --%>
        <div class="p-4 lg:p-6">
          <%= case @live_action do %>
            <% :seating -> %>
              <.seating_content {assigns} />
            <% :users -> %>
              <.users_content {assigns} />
            <% :badges -> %>
              <.badges_content {assigns} />
            <% :scanners -> %>
              <.scanners_content {assigns} />
            <% _ -> %>
              <div>Loading...</div>
          <% end %>
        </div>
      </div>

      <div class="drawer-side z-40">
        <label for="settings-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <.settings_sidebar live_action={@live_action} is_user_auth={@is_user_auth} />
      </div>
    </div>
    """
  end

  # ============================================================================
  # Sidebar Component
  # ============================================================================

  defp settings_sidebar(assigns) do
    ~H"""
    <ul class="menu bg-base-200 min-h-full w-64 p-4 pt-6">
      <li class="menu-title text-base-content/60 text-xs uppercase tracking-wider mb-2">
        Settings
      </li>

      <%!-- Seating - available to all authenticated users --%>
      <li>
        <.link
          patch={~p"/settings/seating"}
          class={["flex items-center gap-3", @live_action == :seating && "active"]}
        >
          <Icons.squares_2x2 class="w-5 h-5" />
          <span>Seating Configuration</span>
        </.link>
      </li>

      <%!-- User-only sections --%>
      <%= if @is_user_auth do %>
        <li>
          <.link
            patch={~p"/settings/users"}
            class={["flex items-center gap-3", @live_action == :users && "active"]}
          >
            <Icons.users class="w-5 h-5" />
            <span>Users</span>
          </.link>
        </li>
        <li>
          <.link
            patch={~p"/settings/badges"}
            class={["flex items-center gap-3", @live_action == :badges && "active"]}
          >
            <Icons.identification class="w-5 h-5" />
            <span>Badges</span>
          </.link>
        </li>
      <% end %>

      <%!-- Scanners --%>
      <li>
        <.link
          patch={~p"/settings/scanners"}
          class={["flex items-center gap-3", @live_action == :scanners && "active"]}
        >
          <Icons.qr_code class="w-5 h-5" />
          <span>Scanners</span>
        </.link>
      </li>
    </ul>
    """
  end

  # ============================================================================
  # Section: Seating Configuration
  # ============================================================================

  defp seating_content(assigns) do
    ~H"""
    <div class="max-w-6xl">
      <.page_header title="Station Layout Settings" subtitle="Configure the station grid layout displayed on signage" />

      <%!-- Grid Configuration Section --%>
      <.admin_section title="Grid Configuration">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
          <%!-- Grid Dimensions --%>
          <div>
            <h3 class="font-medium mb-3">Dimensions</h3>
            <form id="dimensions-form" phx-change="change_dimensions" class="space-y-3">
              <.labeled_input
                label="Columns"
                type="number"
                name="columns"
                value={@columns}
                min={@grid_width}
              />
              <.labeled_input
                label="Rows"
                type="number"
                name="rows"
                value={@rows}
                min={@grid_height}
              />
            </form>
          </div>

          <%!-- Station Count --%>
          <div>
            <h3 class="font-medium mb-3">Station Count</h3>
            <form id="station-count-form" phx-change="change_station_count">
              <.labeled_input
                label="Stations"
                type="number"
                name="station_count"
                value={@station_count}
                min={1}
                max={"#{@rows * @columns}"}
              />
            </form>
            <p class="text-xs text-base-content/50 mt-2">Max: {@rows * @columns}</p>
          </div>

          <%!-- Aisle Gaps --%>
          <div>
            <h3 class="font-medium mb-3">Aisle Gaps</h3>
            <form id="padding-form" phx-change="change_padding" class="space-y-3">
              <.labeled_input
                label="Col gap"
                type="number"
                name="colpad"
                value={@colpad}
                min={1}
                max={15}
              />
              <.labeled_input
                label="Row gap"
                type="number"
                name="rowpad"
                value={@rowpad}
                min={1}
                max={15}
              />
            </form>
          </div>
        </div>
      </.admin_section>

      <%!-- Layout Tools Section --%>
      <.admin_section title="Layout Tools">
        <p class="text-sm text-base-content/60 mb-4">Transform station numbering or drag stations in the preview to manually reorder.</p>

        <div class="flex flex-wrap gap-6 items-end">
          <div>
            <span class="text-xs text-base-content/50 uppercase tracking-wide">Mirror Rows</span>
            <div class="flex gap-2 mt-1">
              <button class="btn btn-sm" phx-click="horizontal_mirror_even">
                <Icons.double_sided_arrow_horizontal /> Even
              </button>
              <button class="btn btn-sm" phx-click="horizontal_mirror_odd">
                <Icons.double_sided_arrow_horizontal /> Odd
              </button>
            </div>
          </div>

          <div>
            <span class="text-xs text-base-content/50 uppercase tracking-wide">Mirror Columns</span>
            <div class="flex gap-2 mt-1">
              <button class="btn btn-sm" phx-click="vertical_mirror_even">
                <Icons.double_sided_arrow_vertical /> Even
              </button>
              <button class="btn btn-sm" phx-click="vertical_mirror_odd">
                <Icons.double_sided_arrow_vertical /> Odd
              </button>
            </div>
          </div>

          <div>
            <span class="text-xs text-base-content/50 uppercase tracking-wide">Rotate</span>
            <div class="mt-1">
              <button class="btn btn-sm" phx-click="diagonal_mirror">
                <Icons.refresh /> Transpose
              </button>
            </div>
          </div>

          <div>
            <span class="text-xs text-base-content/50 uppercase tracking-wide">Reset</span>
            <div class="flex gap-2 mt-1">
              <button class="btn btn-sm btn-warning" phx-click="reset_grid_column_major">
                <Icons.x /> Column Major
              </button>
              <button class="btn btn-sm btn-warning" phx-click="reset_grid_row_major">
                <Icons.x /> Row Major
              </button>
            </div>
          </div>
        </div>
      </.admin_section>

      <%!-- Layout Preview Section --%>
      <section class="mb-10">
        <div class="flex justify-between items-center mb-4 border-b border-base-300 pb-2">
          <h2 class="text-xl font-semibold">Layout Preview</h2>
          <button class="btn btn-primary" phx-click="save">Save Layout</button>
        </div>

        <div id="station-grid" phx-hook="ButtonGridHook" class="flex flex-col gap-4 w-full p-4">
          <%!-- Group rows into table rows (separated by rowpad) --%>
          <% row_groups = group_by_padding(0..(@rows - 1), @rowpad) %>
          <% rows_per_table = if @rowpad > 1, do: @rowpad, else: @rows %>
          <% cols_per_table = if @colpad > 1, do: @colpad, else: @columns %>
          <%= for row_group <- row_groups do %>
            <div class="flex flex-row gap-4">
              <%!-- Group columns into tables (separated by colpad) --%>
              <% col_groups = group_by_padding(0..(@columns - 1), @colpad) %>
              <%= for col_group <- col_groups do %>
                <%!-- Calculate how many rows to render (pad partial tables) --%>
                <% actual_rows = length(row_group) %>
                <% render_rows = max(actual_rows, rows_per_table) %>
                <% actual_cols = length(col_group) %>
                <% render_cols = max(actual_cols, cols_per_table) %>
                <div class="flex-1 bg-base-200 border-2 border-base-300 rounded-xl p-2 flex flex-col gap-1">
                  <%!-- Render rows, padding partial tables to full height --%>
                  <%= for row_idx <- 0..(render_rows - 1) do %>
                    <% r = Enum.at(row_group, row_idx) %>
                    <div class="flex flex-row h-11">
                      <%= for col_idx <- 0..(render_cols - 1) do %>
                        <% c = Enum.at(col_group, col_idx) %>
                        <div class="flex flex-col flex-1 grow mx-0.5">
                          <%= if r != nil and c != nil do %>
                            <% station_num = @grid |> Map.get({c, r}) %>
                            <%= if !is_nil(station_num) do %>
                              <div class="btn btn-warning h-full" station-x={"#{c}"} station-y={"#{r}"} draggable="true">
                                {Map.get(@grid, {c, r})}
                              </div>
                            <% else %>
                              <div class="btn btn-outline btn-ghost h-full" station-x={"#{c}"} station-y={"#{r}"}></div>
                            <% end %>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </section>
    </div>
    <script>
      let hooks = {};
      let draggedElement = null;

      hooks.ButtonGridHook = {
        mounted() {
          const container = document.getElementById('station-grid');
          container.addEventListener('dragstart', event => {
            if (!event.target.matches('[station-x]')) return;
            draggedElement = event.target;
          });

          container.addEventListener("drop", event => {
          if (!event.target.matches('[station-x]')) return;
            // Push an event to the LiveView with some parameters
            let from = { x: parseInt(draggedElement.getAttribute("station-x")), y: parseInt(draggedElement.getAttribute("station-y")) };
            let to = { x: parseInt(event.target.getAttribute("station-x")), y: parseInt(event.target.getAttribute("station-y")) };
            this.pushEvent("move", { from: from, to: to });
          });
        }
      };
      window.customHooks = hooks;
    </script>
    """
  end

  # ============================================================================
  # Section: Users
  # ============================================================================

  defp users_content(assigns) do
    ~H"""
    <div class="max-w-4xl">
      <.page_header title="Admin Users" subtitle="Manage admin user accounts with full access permissions.">
        <:trailing>
          <span class="text-base-content/60">{length(@users)} users</span>
        </:trailing>
      </.page_header>

      <.admin_section title="Create New User">
        <%= if @show_create_form do %>
          <.form for={@form} id="create-user-form" phx-submit="create_user" class="space-y-4">
            <%= if @form_error do %>
              <div class="alert alert-error">
                <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span>{@form_error}</span>
              </div>
            <% end %>

            <div class="form-control">
              <label class="label">
                <span class="label-text">Name</span>
              </label>
              <input
                type="text"
                name="user[name]"
                value={@form[:name].value}
                class="input input-bordered w-full max-w-md"
                required
                autocomplete="off"
              />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text">Email</span>
              </label>
              <input
                type="email"
                name="user[email]"
                value={@form[:email].value}
                class="input input-bordered w-full max-w-md"
                required
                autocomplete="off"
              />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text">Password (min 12 characters)</span>
              </label>
              <input
                type="password"
                name="user[password]"
                class="input input-bordered w-full max-w-md"
                required
                minlength="12"
                autocomplete="new-password"
              />
            </div>

            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary">
                Create User
              </button>
              <button type="button" class="btn btn-ghost" phx-click="toggle_create_form">
                Cancel
              </button>
            </div>
          </.form>
        <% else %>
          <button class="btn btn-primary" phx-click="toggle_create_form">
            + Add User
          </button>
        <% end %>
      </.admin_section>

      <.admin_section title="Existing Users">
        <.data_table>
          <:header>
            <th class="text-base-content">ID</th>
            <th class="text-base-content">Name</th>
            <th class="text-base-content">Email</th>
            <th class="text-base-content">Created</th>
            <th class="text-base-content">Actions</th>
          </:header>
          <:row :for={user <- @users}>
            <tr class="hover:bg-base-200">
              <td class="text-base-content/50">{user.id}</td>
              <td>
                {user.name}
                <%= if user.id == @current_scope.user.id do %>
                  <span class="badge badge-info badge-sm ml-2">You</span>
                <% end %>
              </td>
              <td class="font-mono text-sm">{user.email}</td>
              <td class="text-sm">{format_datetime(user.inserted_at)}</td>
              <td>
                <%= if user.id != @current_scope.user.id do %>
                  <button
                    class="btn btn-error btn-sm"
                    phx-click="delete_user"
                    phx-value-id={user.id}
                    data-confirm="Are you sure you want to delete this user?"
                  >
                    Delete
                  </button>
                <% else %>
                  <span class="text-base-content/50 text-sm">-</span>
                <% end %>
              </td>
            </tr>
          </:row>
        </.data_table>
      </.admin_section>
    </div>
    """
  end

  # ============================================================================
  # Section: Badges
  # ============================================================================

  defp badges_content(assigns) do
    ~H"""
    <div class="max-w-4xl">
      <.page_header title="Admin Badges" subtitle="Manage admin badges for emergency backdoor access. Badge authentication has limited permissions.">
        <:trailing>
          <span class="text-base-content/60">{length(@badges)} badges</span>
        </:trailing>
      </.page_header>

      <.admin_section title="Create New Badge">
        <%= if @show_create_form do %>
          <.form for={@form} id="create-badge-form" phx-submit="create_badge" class="space-y-4">
            <%= if @form_error do %>
              <div class="alert alert-error">
                <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span>{@form_error}</span>
              </div>
            <% end %>

            <div class="form-control">
              <label class="label">
                <span class="label-text">Badge Number</span>
              </label>
              <input
                type="text"
                name="badge[badge_number]"
                value={@form[:badge_number].value}
                class="input input-bordered w-full max-w-md"
                placeholder="e.g. ADMIN-002"
                required
                autocomplete="off"
              />
              <label class="label">
                <span class="label-text-alt">This is what gets scanned or entered at login</span>
              </label>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text">Label</span>
              </label>
              <input
                type="text"
                name="badge[label]"
                value={@form[:label].value}
                class="input input-bordered w-full max-w-md"
                placeholder="e.g. Tech Support"
                required
              />
              <label class="label">
                <span class="label-text-alt">Displayed in the nav when logged in</span>
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-2">
                <input
                  type="checkbox"
                  name="badge[enabled]"
                  value="true"
                  checked={@form[:enabled].value == "true"}
                  class="checkbox"
                />
                <span class="label-text">Enabled</span>
              </label>
            </div>

            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary">
                Create Badge
              </button>
              <button type="button" class="btn btn-ghost" phx-click="toggle_create_form">
                Cancel
              </button>
            </div>
          </.form>
        <% else %>
          <button class="btn btn-primary" phx-click="toggle_create_form">
            + Add Badge
          </button>
        <% end %>
      </.admin_section>

      <.admin_section title="Existing Badges">
        <%= if Enum.empty?(@badges) do %>
          <p class="text-base-content/60">No badges configured.</p>
        <% else %>
          <.data_table>
            <:header>
              <th class="text-base-content">ID</th>
              <th class="text-base-content">Badge Number</th>
              <th class="text-base-content">Label</th>
              <th class="text-base-content">Status</th>
              <th class="text-base-content">Created</th>
              <th class="text-base-content">Actions</th>
            </:header>
            <:row :for={badge <- @badges}>
              <tr class="hover:bg-base-200">
                <td class="text-base-content/50">{badge.id}</td>
                <td class="font-mono font-semibold">{badge.badge_number}</td>
                <td>{badge.label}</td>
                <td>
                  <%= if badge.enabled do %>
                    <span class="badge badge-success">Enabled</span>
                  <% else %>
                    <span class="badge badge-error">Disabled</span>
                  <% end %>
                </td>
                <td class="text-sm">{format_datetime(badge.inserted_at)}</td>
                <td class="flex gap-1">
                  <button
                    class={["btn btn-sm", if(badge.enabled, do: "btn-warning", else: "btn-success")]}
                    phx-click="toggle_badge"
                    phx-value-id={badge.id}
                  >
                    {if badge.enabled, do: "Disable", else: "Enable"}
                  </button>
                  <button
                    class="btn btn-error btn-sm"
                    phx-click="delete_badge"
                    phx-value-id={badge.id}
                    data-confirm="Are you sure you want to delete this badge?"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            </:row>
          </.data_table>
        <% end %>
      </.admin_section>

      <.admin_section title="Badge Permissions" title_class="text-warning">
        <div class="alert alert-warning">
          <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
            />
          </svg>
          <div>
            <p class="font-bold">Badge authentication has limited permissions:</p>
            <ul class="list-disc list-inside mt-2">
              <li>Can access admin pages (Tournaments, Settings, Logs)</li>
              <li>Cannot manage users or badges (this page)</li>
              <li>Sessions are browser-only (no persistent login)</li>
            </ul>
          </div>
        </div>
      </.admin_section>
    </div>
    """
  end

  # ============================================================================
  # Section: Scanners
  # ============================================================================

  defp scanners_content(assigns) do
    ~H"""
    <div class="max-w-4xl" id="scanners-section" phx-hook="BluetoothProvisioning">
      <.page_header title="External Badge Scanners" subtitle="Configure ESP32 badge scanner devices for sign-out stations.">
        <:trailing>
          <span class="text-base-content/60">{length(@scanners)} scanners</span>
        </:trailing>
      </.page_header>

      <%!-- Browser Support Warning --%>
      <%= case @bluetooth_status do %>
        <% :requires_https -> %>
          <div class="alert alert-warning mb-6">
            <Icons.exclamation_triangle class="w-6 h-6" />
            <div>
              <h3 class="font-bold">HTTPS Required for Bluetooth</h3>
              <div class="text-sm">
                WebBluetooth requires a secure connection. Access this page via HTTPS (port 4001 in dev) or localhost.
              </div>
            </div>
          </div>
        <% :not_available -> %>
          <div class="alert alert-warning mb-6">
            <Icons.exclamation_triangle class="w-6 h-6" />
            <div>
              <h3 class="font-bold">WebBluetooth Not Supported</h3>
              <div class="text-sm">
                Your browser does not support WebBluetooth. Use Chrome or Edge on desktop/Android for Bluetooth provisioning.
              </div>
            </div>
          </div>
        <% :supported -> %>
      <% end %>

      <%!-- WiFi Configuration Section --%>
      <.admin_section title="WiFi Configuration">
        <%= if not @can_edit_wifi do %>
          <div class="alert alert-warning mb-4">
            <Icons.lock_closed class="w-5 h-5" />
            <span>WiFi settings are locked while scanners exist. Delete all scanners to modify.</span>
          </div>
        <% end %>

        <%= if @wifi_form_error do %>
          <div class="alert alert-error mb-4">
            <Icons.x_circle class="w-5 h-5" />
            <span>{@wifi_form_error}</span>
          </div>
        <% end %>

        <.form for={@wifi_form} id="wifi-form" phx-submit="save_wifi" class="space-y-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="form-control">
              <label class="label">
                <span class="label-text">WiFi Network (SSID)</span>
              </label>
              <input
                type="text"
                name="wifi[ssid]"
                value={@wifi_form[:ssid].value}
                class="input input-bordered w-full"
                placeholder="Event WiFi Network"
                required
                disabled={not @can_edit_wifi}
                autocomplete="off"
              />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text">WiFi Password</span>
              </label>
              <input
                type="password"
                name="wifi[password]"
                value={@wifi_form[:password].value}
                class="input input-bordered w-full"
                placeholder="********"
                required
                disabled={not @can_edit_wifi}
                autocomplete="new-password"
              />
            </div>
          </div>

          <%= if @can_edit_wifi do %>
            <button type="submit" class="btn btn-primary">
              Save WiFi Settings
            </button>
          <% end %>

          <%= if @wifi_configured do %>
            <div class="badge badge-success gap-2 ml-2">
              <Icons.check class="w-4 h-4" /> Configured
            </div>
          <% end %>
        </.form>
      </.admin_section>

      <%!-- Add Scanner Section --%>
      <.admin_section title="Add Scanner">
        <%= if not @wifi_configured do %>
          <div class="alert alert-info">
            <Icons.information_circle class="w-5 h-5" />
            <span>Configure WiFi settings above before adding scanners.</span>
          </div>
        <% else %>
          <%= if @show_create_form do %>
            <.form for={@scanner_form} id="create-scanner-form" phx-submit="create_scanner" class="space-y-4">
              <%= if @scanner_form_error do %>
                <div class="alert alert-error">
                  <Icons.x_circle class="w-5 h-5" />
                  <span>{@scanner_form_error}</span>
                </div>
              <% end %>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Scanner Name</span>
                </label>
                <input
                  type="text"
                  name="scanner[name]"
                  value={@scanner_form[:name].value}
                  class="input input-bordered w-full max-w-md"
                  placeholder="Exit A"
                  required
                  autocomplete="off"
                />
                <label class="label">
                  <span class="label-text-alt">A friendly name to identify this scanner</span>
                </label>
              </div>

              <div class="flex gap-2">
                <button type="submit" class="btn btn-primary">
                  Create Scanner
                </button>
                <button type="button" class="btn btn-ghost" phx-click="toggle_create_form">
                  Cancel
                </button>
              </div>
            </.form>
          <% else %>
            <button class="btn btn-primary" phx-click="toggle_create_form">
              + Add Scanner
            </button>
          <% end %>
        <% end %>
      </.admin_section>

      <%!-- Scanners List --%>
      <.admin_section title="Scanners">
        <%= if Enum.empty?(@scanners) do %>
          <p class="text-base-content/60">No scanners configured yet.</p>
        <% else %>
          <div class="space-y-3">
            <%= for scanner <- @scanners do %>
              <div class={["card bg-base-200 shadow-sm", scanner.revoked_at && "opacity-60"]}>
                <div class="card-body p-4">
                  <div class="flex flex-wrap items-center justify-between gap-4">
                    <div class="flex-1 min-w-0">
                      <h3 class="font-semibold text-lg">{scanner.name}</h3>
                      <div class="flex flex-wrap items-center gap-3 text-sm text-base-content/70 mt-1">
                        <span class="font-mono">{scanner.token_prefix}...</span>
                        <.scanner_status scanner={scanner} />
                      </div>
                      <div class="text-xs text-base-content/50 mt-1">
                        <%= if scanner.last_seen_at do %>
                          Last seen: {format_relative_time(scanner.last_seen_at)}
                        <% else %>
                          Never connected
                        <% end %>
                      </div>
                    </div>

                    <div class="flex gap-2">
                      <%= if is_nil(scanner.revoked_at) do %>
                        <button
                          class="btn btn-sm btn-primary"
                          phx-click="start_provisioning"
                          phx-value-id={scanner.id}
                          disabled={@bluetooth_status != :supported}
                        >
                          <Icons.signal class="w-4 h-4" /> Provision
                        </button>
                        <button
                          class="btn btn-sm btn-warning"
                          phx-click="revoke_scanner"
                          phx-value-id={scanner.id}
                          data-confirm="Revoke this scanner's access? It will no longer be able to cancel reservations."
                        >
                          Revoke
                        </button>
                      <% end %>
                      <button
                        class="btn btn-sm btn-error"
                        phx-click="delete_scanner"
                        phx-value-id={scanner.id}
                        data-confirm="Permanently delete this scanner?"
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </.admin_section>

      <%!-- Provisioning Modal --%>
      <%= if @provisioning_scanner do %>
        <.provisioning_modal
          scanner={@provisioning_scanner}
          ble_status={@ble_status}
          ble_connected={@ble_connected}
          ble_device_name={@ble_device_name}
          api_url_override={@api_url_override}
        />
      <% end %>

      <%!-- Help --%>
      <.admin_section title="Help">
        <%!-- Factory Reset --%>
        <div class="collapse collapse-arrow bg-base-200 mb-2">
          <input type="checkbox" />
          <div class="collapse-title font-medium">
            <Icons.question_mark_circle class="w-5 h-5 inline mr-2" /> How to factory reset a scanner
          </div>
          <div class="collapse-content">
            <div class="prose prose-sm max-w-none pt-2">
              <p class="font-semibold">To erase stored configuration and return to provisioning mode:</p>
              <ol class="list-decimal list-inside space-y-1 mt-2">
                <li><strong>Power off</strong> the scanner</li>
                <li><strong>Hold the BOOT button</strong> (small button on the ESP32 board)</li>
                <li><strong>Power on</strong> while holding the button</li>
                <li><strong>Continue holding for 5 seconds</strong></li>
                <li>Release - the scanner will erase its configuration and reboot</li>
              </ol>
              <p class="mt-3">The LED will pulse <span class="text-cyan-400 font-semibold">cyan</span> when in provisioning mode, ready for Bluetooth setup.</p>
            </div>
          </div>
        </div>

        <%!-- API Info --%>
        <div class="collapse collapse-arrow bg-base-200">
          <input type="checkbox" />
          <div class="collapse-title font-medium">
            <Icons.information_circle class="w-5 h-5 inline mr-2" /> API Information
          </div>
          <div class="collapse-content">
            <div class="prose prose-sm max-w-none pt-2">
              <p>Scanners use the following API endpoint to cancel reservations:</p>
              <code class="block bg-base-200 p-2 rounded text-sm border border-base-300">
                POST {LanpartyseatingWeb.Endpoint.url()}/api/v1/reservations/cancel
              </code>
              <p class="mt-2">
                Include the scanner token in the Authorization header: <code>Authorization: Bearer lpss_...</code>
              </p>
              <%= if Mix.env() == :dev do %>
                <p class="mt-2">
                  <.link href="/api/docs" target="_blank" class="link link-primary">
                    View API Documentation (Swagger UI)
                  </.link>
                </p>
              <% end %>
            </div>
          </div>
        </div>
      </.admin_section>
    </div>
    """
  end

  defp scanner_status(assigns) do
    ~H"""
    <%= cond do %>
      <% @scanner.revoked_at -> %>
        <span class="badge badge-error">Revoked</span>
      <% @scanner.provisioned_at -> %>
        <span class="badge badge-success">Provisioned</span>
      <% true -> %>
        <span class="badge badge-warning">Not Provisioned</span>
    <% end %>
    """
  end

  defp provisioning_modal(assigns) do
    ~H"""
    <div class="modal modal-open">
      <div class="modal-box max-w-lg">
        <h3 class="font-bold text-lg mb-4">
          Provision Scanner: {@scanner.name}
        </h3>

        <div class="space-y-4">
          <%!-- Instructions --%>
          <div class="alert alert-info">
            <Icons.information_circle class="w-5 h-5" />
            <div>
              <p class="font-semibold">Put the scanner in provisioning mode</p>
              <p class="text-sm">The LED should be pulsing cyan. Hold BOOT for 5s during power-on to reset.</p>
            </div>
          </div>

          <%!-- Status Display --%>
          <%= if @ble_status do %>
            <div class={[
              "alert",
              @ble_status.status == "error" && "alert-error",
              @ble_status.status == "connected" && "alert-success",
              @ble_status.status in ["connecting", "establishing", "provisioning"] && "alert-info"
            ]}>
              <%= if @ble_status.status in ["connecting", "establishing", "provisioning"] do %>
                <span class="loading loading-spinner loading-sm"></span>
              <% end %>
              <span>{@ble_status.message}</span>
            </div>
          <% end %>

          <%!-- Connected Device Info --%>
          <%= if @ble_connected do %>
            <div class="bg-base-200 p-3 rounded">
              <span class="text-sm text-base-content/70">Connected to:</span>
              <span class="font-mono ml-2">{@ble_device_name}</span>
            </div>

            <%!-- API URL Override (dev only) --%>
            <div class="form-control">
              <label class="label">
                <span class="label-text">API URL Override (optional)</span>
              </label>
              <input
                type="text"
                value={@api_url_override}
                phx-keyup="update_api_url_override"
                phx-debounce="300"
                class="input input-bordered input-sm w-full"
                placeholder={LanpartyseatingWeb.Endpoint.url()}
              />
              <label class="label">
                <span class="label-text-alt text-base-content/50">Leave empty to use default. For dev, use your local IP.</span>
              </label>
            </div>
          <% end %>

          <%!-- Action Buttons --%>
          <div class="flex gap-2">
            <%= if not @ble_connected do %>
              <button class="btn btn-primary" phx-click="ble_connect">
                <Icons.signal class="w-4 h-4" /> Connect via Bluetooth
              </button>
            <% else %>
              <button class="btn btn-success" phx-click="ble_provision">
                <Icons.arrow_up_tray class="w-4 h-4" /> Send Configuration
              </button>
              <button class="btn btn-ghost" phx-click="ble_disconnect">
                Disconnect
              </button>
            <% end %>
          </div>
        </div>

        <div class="modal-action">
          <button class="btn btn-ghost" phx-click="cancel_provisioning">
            Cancel
          </button>
        </div>
      </div>
      <div class="modal-backdrop bg-black/50" phx-click="cancel_provisioning"></div>
    </div>
    """
  end

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} min ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)} hours ago"
      true -> "#{div(diff_seconds, 86400)} days ago"
    end
  end
end
