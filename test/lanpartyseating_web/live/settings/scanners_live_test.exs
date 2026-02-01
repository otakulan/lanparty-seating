defmodule LanpartyseatingWeb.Settings.ScannersLiveTest do
  use LanpartyseatingWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lanpartyseating.AccountsFixtures
  import Lanpartyseating.ScannerFixtures
  import LanpartyseatingWeb.ConnCase

  alias Lanpartyseating.ScannerLogic

  # ============================================================================
  # Authentication Tests
  # ============================================================================

  describe "authentication" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings/scanners")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "accessible with user auth", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture())
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")
      assert has_element?(view, "h1", "External Badge Scanners")
    end

    test "accessible with badge auth", %{conn: conn} do
      conn = conn |> log_in_badge(admin_badge_fixture())
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")
      assert has_element?(view, "h1", "External Badge Scanners")
    end
  end

  # ============================================================================
  # Sidebar Tests
  # ============================================================================

  describe "sidebar" do
    setup :register_and_log_in_user

    test "shows Scanners link in sidebar", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")
      assert has_element?(view, ~s|.drawer-side a[href="/settings/scanners"]|, "Scanners")
    end

    test "Scanners link is active on scanners page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")
      assert has_element?(view, ~s|.drawer-side a[href="/settings/scanners"].active|)
    end
  end

  # ============================================================================
  # WiFi Configuration Tests
  # ============================================================================

  describe "WiFi configuration section" do
    setup :register_and_log_in_user

    test "shows form when not configured", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert has_element?(view, ~s|input[name="wifi[ssid]"]|)
      assert has_element?(view, ~s|input[name="wifi[password]"]|)
      assert has_element?(view, "button", "Save WiFi Settings")
      # Should not show configured badge
      refute has_element?(view, ".badge-success", "Configured")
    end

    test "shows configured badge when configured", %{conn: conn} do
      wifi_config_fixture()
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert has_element?(view, ".badge-success", "Configured")
    end

    test "saves WiFi config with valid params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      view
      |> form("#wifi-form", %{
        "wifi" => %{"ssid" => "TestNetwork", "password" => "testpass123"},
      })
      |> render_submit()

      assert has_element?(view, ".badge-success", "Configured")
      assert render(view) =~ "WiFi configuration saved"
    end

    test "shows error for invalid params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      view
      |> form("#wifi-form", %{
        "wifi" => %{"ssid" => "", "password" => ""},
      })
      |> render_submit()

      assert has_element?(view, ".alert-error")
    end

    test "locks WiFi form when scanners exist", %{conn: conn} do
      wifi_config_fixture()
      scanner_fixture()

      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert has_element?(view, ".alert-warning", "WiFi settings are locked")
      assert has_element?(view, ~s|input[name="wifi[ssid]"][disabled]|)
    end
  end

  # ============================================================================
  # Scanner CRUD Tests
  # ============================================================================

  describe "scanner CRUD" do
    setup :register_and_log_in_user

    setup do
      wifi_config_fixture()
      :ok
    end

    test "hides create form by default", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      refute has_element?(view, "#create-scanner-form")
      assert has_element?(view, "button", "+ Add Scanner")
    end

    test "shows create form when Add Scanner clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      view |> element("button", "+ Add Scanner") |> render_click()

      assert has_element?(view, "#create-scanner-form")
      assert has_element?(view, ~s|input[name="scanner[name]"]|)
    end

    test "creates scanner with valid name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      view |> element("button", "+ Add Scanner") |> render_click()

      view
      |> form("#create-scanner-form", %{
        "scanner" => %{"name" => "Exit Door A"},
      })
      |> render_submit()

      # Form should be hidden after success
      refute has_element?(view, "#create-scanner-form")

      # Scanner should appear in list
      assert has_element?(view, "h3", "Exit Door A")
      assert render(view) =~ "Scanner created"
    end

    test "shows error for empty name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      view |> element("button", "+ Add Scanner") |> render_click()

      view
      |> form("#create-scanner-form", %{
        "scanner" => %{"name" => ""},
      })
      |> render_submit()

      assert has_element?(view, "#create-scanner-form")
      assert has_element?(view, ".alert-error")
    end

    test "lists created scanners", %{conn: conn} do
      {scanner1, _} = scanner_fixture(%{"name" => "Scanner One"})
      {scanner2, _} = scanner_fixture(%{"name" => "Scanner Two"})

      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert has_element?(view, "h3", scanner1.name)
      assert has_element?(view, "h3", scanner2.name)
    end

    test "revokes scanner", %{conn: conn} do
      {scanner, _} = scanner_fixture(%{"name" => "To Revoke"})

      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      view
      |> element(~s|button[phx-click="revoke_scanner"][phx-value-id="#{scanner.id}"]|)
      |> render_click()

      assert render(view) =~ "Scanner revoked"
      assert has_element?(view, ".badge-error", "Revoked")
    end

    test "deletes scanner", %{conn: conn} do
      {scanner, _} = scanner_fixture(%{"name" => "To Delete"})

      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      view
      |> element(~s|button[phx-click="delete_scanner"][phx-value-id="#{scanner.id}"]|)
      |> render_click()

      assert render(view) =~ "Scanner deleted"
      refute has_element?(view, "h3", "To Delete")
    end
  end

  # ============================================================================
  # Scanner List Display Tests
  # ============================================================================

  describe "scanner list display" do
    setup :register_and_log_in_user

    setup do
      wifi_config_fixture()
      :ok
    end

    test "shows 'Not Provisioned' badge for new scanners", %{conn: conn} do
      scanner_fixture(%{"name" => "New Scanner"})

      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert has_element?(view, ".badge-warning", "Not Provisioned")
    end

    test "shows 'Provisioned' badge for provisioned scanners", %{conn: conn} do
      provisioned_scanner_fixture(%{"name" => "Provisioned Scanner"})

      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert has_element?(view, ".badge-success", "Provisioned")
    end

    test "shows 'Revoked' badge for revoked scanners", %{conn: conn} do
      revoked_scanner_fixture(%{"name" => "Revoked Scanner"})

      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert has_element?(view, ".badge-error", "Revoked")
    end

    test "shows 'Never connected' for scanners without last_seen", %{conn: conn} do
      scanner_fixture(%{"name" => "Never Connected"})

      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert render(view) =~ "Never connected"
    end

    test "shows last seen time for active scanners", %{conn: conn} do
      {scanner, _} = scanner_fixture(%{"name" => "Active Scanner"})
      ScannerLogic.update_last_seen(scanner.id)

      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert render(view) =~ "Last seen:"
    end

    test "shows token prefix for scanners", %{conn: conn} do
      {scanner, _} = scanner_fixture(%{"name" => "With Token"})

      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert render(view) =~ scanner.token_prefix
    end
  end

  # ============================================================================
  # PubSub Tests
  # ============================================================================

  describe "PubSub updates" do
    setup :register_and_log_in_user

    setup do
      wifi_config_fixture()
      :ok
    end

    test "refreshes scanner list when scanner_seen broadcast received", %{conn: conn} do
      {scanner, _} = scanner_fixture(%{"name" => "PubSub Test"})

      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      # Initially shows "Never connected"
      assert render(view) =~ "Never connected"

      # Simulate scanner being seen (this broadcasts to PubSub)
      ScannerLogic.update_last_seen(scanner.id)

      # Give the PubSub message time to be processed
      Process.sleep(50)

      # Should now show last seen time
      assert render(view) =~ "Last seen:"
    end
  end

  # ============================================================================
  # Help Section Tests
  # ============================================================================

  describe "help section" do
    setup :register_and_log_in_user

    test "shows factory reset instructions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert render(view) =~ "How to factory reset a scanner"
      assert render(view) =~ "BOOT button"
    end

    test "shows API information", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert render(view) =~ "API Information"
      assert render(view) =~ "/api/v1/reservations/cancel"
    end
  end

  # ============================================================================
  # Empty State Tests
  # ============================================================================

  describe "empty states" do
    setup :register_and_log_in_user

    test "shows info message when WiFi not configured", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert has_element?(view, ".alert-info", "Configure WiFi settings above before adding scanners")
    end

    test "shows empty message when no scanners exist", %{conn: conn} do
      wifi_config_fixture()
      {:ok, view, _html} = live(conn, ~p"/settings/scanners")

      assert render(view) =~ "No scanners configured yet"
    end
  end
end
