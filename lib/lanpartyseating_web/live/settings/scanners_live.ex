defmodule LanpartyseatingWeb.Settings.ScannersLive do
  @moduledoc """
  Settings page for external badge scanner management.
  """
  use LanpartyseatingWeb, :live_view
  import LanpartyseatingWeb.Helpers, only: [format_relative_time: 1]

  alias Lanpartyseating.ScannerLogic
  alias LanpartyseatingWeb.Components.SettingsNav

  # ============================================================================
  # Mount & Handle Params
  # ============================================================================

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Lanpartyseating.PubSub, "scanner_update")
    end

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    # Redirect badge-auth users - they don't have access to scanner management
    if socket.assigns.is_user_auth do
      {:noreply, load_data(socket)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Full admin access required")
       |> push_navigate(to: ~p"/settings/seating", replace: true)}
    end
  end

  defp load_data(socket) do
    wifi_config = ScannerLogic.get_wifi_config()
    scanners = ScannerLogic.list_scanners()
    can_edit_wifi = ScannerLogic.can_edit_wifi_config?()

    # Only load SSID, not password - password should not be sent to browser
    ssid =
      case wifi_config do
        {:ok, config} -> config.ssid
        {:error, :not_configured} -> ""
      end

    socket
    |> assign(:scanners, scanners)
    |> assign(:wifi_configured, match?({:ok, _}, wifi_config))
    |> assign(:can_edit_wifi, can_edit_wifi)
    |> assign(:wifi_form, to_form(%{"ssid" => ssid, "password" => ""}, as: "wifi"))
    |> assign(:wifi_form_error, nil)
    |> assign(:show_create_form, false)
    |> assign(:scanner_form, to_form(%{"name" => ""}, as: "scanner"))
    |> assign(:scanner_form_error, nil)
    |> assign(:provisioning_scanner, nil)
    |> assign(:ble_status, nil)
    |> assign(:ble_connected, false)
    |> assign(:ble_device_name, nil)
    |> assign(:api_url_override, "")
    |> assign(:bluetooth_status, :supported)
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  def handle_event("toggle_create_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_form, !socket.assigns.show_create_form)
     |> assign(:scanner_form, to_form(%{"name" => ""}, as: "scanner"))
     |> assign(:scanner_form_error, nil)}
  end

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
        case ScannerLogic.regenerate_token(scanner.id) do
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
  def handle_event("bluetooth_unsupported", %{"reason" => "requires_https"}, socket) do
    {:noreply, assign(socket, :bluetooth_status, :requires_https)}
  end

  def handle_event("bluetooth_unsupported", %{"reason" => "not_available"}, socket) do
    {:noreply, assign(socket, :bluetooth_status, :not_available)}
  end

  def handle_event("bluetooth_unsupported", _params, socket) do
    # Fallback for unknown reasons
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

  # ============================================================================
  # PubSub Handlers
  # ============================================================================

  def handle_info({:scanner_seen, _scanner_id}, socket) do
    # Refresh scanner list when any scanner is seen (updates last_seen_at display)
    {:noreply, assign(socket, :scanners, ScannerLogic.list_scanners())}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
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
          <span class="text-lg font-bold">Scanners</span>
        </div>

        <%!-- Main content area --%>
        <div class="p-4 lg:p-6">
          <.scanners_content {assigns} />
        </div>
      </div>

      <div class="drawer-side z-40">
        <label for="settings-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <SettingsNav.settings_nav current_page={:scanners} is_user_auth={@is_user_auth} />
      </div>
    </div>
    """
  end

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
                class="input input-bordered w-full"
                placeholder={if @wifi_configured, do: "••••••••  (leave empty to keep current)", else: "Enter password"}
                required={not @wifi_configured}
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
              <div class="card bg-base-200 shadow-sm">
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
                      <button
                        class="btn btn-sm btn-primary"
                        phx-click="start_provisioning"
                        phx-value-id={scanner.id}
                        disabled={@bluetooth_status != :supported}
                      >
                        <Icons.signal class="w-4 h-4" /> Provision
                      </button>
                      <button
                        class="btn btn-sm btn-error"
                        phx-click="delete_scanner"
                        phx-value-id={scanner.id}
                        data-confirm="Permanently delete this scanner? Its token will be invalidated."
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
    <%= if @scanner.provisioned_at do %>
      <span class="badge badge-success">Provisioned</span>
    <% else %>
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
end
