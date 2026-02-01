defmodule LanpartyseatingWeb.SettingsLiveTest do
  use LanpartyseatingWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lanpartyseating.AccountsFixtures
  import LanpartyseatingWeb.ConnCase

  alias Lanpartyseating.Repo
  alias Lanpartyseating.Setting
  alias Lanpartyseating.BadgesLogic

  # Create settings required for the seating page to load
  defp create_settings(_context) do
    settings =
      %Setting{}
      |> Setting.changeset(%{row_padding: 2, column_padding: 1})
      |> Repo.insert!()

    %{settings: settings}
  end

  # ============================================================================
  # Authentication/Authorization Tests
  # ============================================================================

  describe "unauthenticated access" do
    test "redirects from /settings to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "redirects from /settings/seating to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings/seating")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "redirects from /settings/users to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings/users")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "redirects from /settings/badges to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings/badges")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end
  end

  describe "user auth - access control" do
    setup [:register_and_log_in_user, :create_settings]

    test "/settings redirects to /settings/seating", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/settings")
      assert path == ~p"/settings/seating"
    end

    test "can access /settings/seating", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seating")
      assert has_element?(view, "h1", "Station Layout Settings")
    end

    test "can access /settings/users", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")
      assert has_element?(view, "h1", "Admin Users")
    end

    test "can access /settings/badges", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")
      assert has_element?(view, "h1", "Badges")
    end
  end

  describe "badge auth - access control" do
    setup [:register_and_log_in_badge, :create_settings]

    test "can access /settings/seating", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seating")
      assert has_element?(view, "h1", "Station Layout Settings")
    end

    test "redirected from /settings/users with error flash", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: path, flash: flash}}} = live(conn, ~p"/settings/users")
      assert path == ~p"/settings/seating"
      assert flash["error"] == "Full admin access required"
    end

    test "redirected from /settings/badges with error flash", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: path, flash: flash}}} = live(conn, ~p"/settings/badges")
      assert path == ~p"/settings/seating"
      assert flash["error"] == "Full admin access required"
    end
  end

  # ============================================================================
  # Sidebar Rendering Tests
  # ============================================================================

  describe "sidebar - user auth" do
    setup [:register_and_log_in_user, :create_settings]

    test "shows all menu items", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seating")

      # Use the drawer-side menu specifically
      assert has_element?(view, ".drawer-side a[href=\"/settings/seating\"]", "Seating Configuration")
      assert has_element?(view, ".drawer-side a[href=\"/settings/users\"]", "Users")
      assert has_element?(view, ".drawer-side a[href=\"/settings/badges\"]", "Badges")
    end

    test "seating link is active on seating page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seating")
      assert has_element?(view, ~s|.drawer-side a[href="/settings/seating"].active|)
    end

    test "users link is active on users page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")
      assert has_element?(view, ~s|.drawer-side a[href="/settings/users"].active|)
    end

    test "badges link is active on badges page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")
      assert has_element?(view, ~s|.drawer-side a[href="/settings/badges"].active|)
    end
  end

  describe "sidebar - badge auth" do
    setup [:register_and_log_in_badge, :create_settings]

    test "shows only seating link, not users or badges", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seating")

      assert has_element?(view, ~s|.drawer-side a[href="/settings/seating"]|, "Seating Configuration")
      refute has_element?(view, ~s|.drawer-side a[href="/settings/users"]|)
      refute has_element?(view, ~s|.drawer-side a[href="/settings/badges"]|)
    end
  end

  describe "sidebar navigation" do
    setup [:register_and_log_in_user, :create_settings]

    test "clicking Users link navigates to /settings/users", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seating")

      {:ok, view, _html} =
        view
        |> element(~s|.drawer-side a[href="/settings/users"]|)
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(view, "h1", "Admin Users")
    end

    test "clicking Badges link navigates to /settings/badges", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seating")

      {:ok, view, _html} =
        view
        |> element(~s|.drawer-side a[href="/settings/badges"]|)
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(view, "h1", "Badges")
    end

    test "clicking Seating link navigates to /settings/seating", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")

      {:ok, view, _html} =
        view
        |> element(~s|.drawer-side a[href="/settings/seating"]|)
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(view, "h1", "Station Layout Settings")
    end
  end

  # ============================================================================
  # Users Section - CRUD Tests
  # ============================================================================

  describe "users section - rendering" do
    setup :register_and_log_in_user

    test "displays page header", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")

      assert has_element?(view, "h1", "Admin Users")
      assert has_element?(view, "p", "Manage admin user accounts")
    end

    test "lists current user in table", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")

      assert has_element?(view, "td", user.email)
      assert has_element?(view, "td", user.name)
    end

    test "shows 'You' badge for current user", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")

      assert has_element?(view, "span.badge", "You")
    end
  end

  describe "users section - create form toggle" do
    setup :register_and_log_in_user

    test "form is hidden by default", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")

      refute has_element?(view, "#create-user-form")
      assert has_element?(view, "button", "+ Add User")
    end

    test "clicking Add User shows form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")

      view |> element("button", "+ Add User") |> render_click()

      assert has_element?(view, "#create-user-form")
      assert has_element?(view, ~s|input[name="user[name]"]|)
      assert has_element?(view, ~s|input[name="user[email]"]|)
      assert has_element?(view, ~s|input[name="user[password]"]|)
    end

    test "clicking Cancel hides form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")

      view |> element("button", "+ Add User") |> render_click()
      assert has_element?(view, "#create-user-form")

      view |> element("button", "Cancel") |> render_click()
      refute has_element?(view, "#create-user-form")
    end
  end

  describe "users section - create user" do
    setup :register_and_log_in_user

    test "create user with valid params succeeds", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")

      view |> element("button", "+ Add User") |> render_click()

      view
      |> form("#create-user-form", %{
        "user" => %{
          "name" => "New Test User",
          "email" => "newuser@example.com",
          "password" => "validpassword123",
        },
      })
      |> render_submit()

      # Form should be hidden after success
      refute has_element?(view, "#create-user-form")

      # New user should appear in table
      assert has_element?(view, "td", "newuser@example.com")
      assert has_element?(view, "td", "New Test User")

      # Success flash
      assert render(view) =~ "User created successfully"
    end

    test "create user with invalid email shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")

      view |> element("button", "+ Add User") |> render_click()

      view
      |> form("#create-user-form", %{
        "user" => %{
          "name" => "Test User",
          "email" => "not-an-email",
          "password" => "validpassword123",
        },
      })
      |> render_submit()

      # Form should still be visible
      assert has_element?(view, "#create-user-form")

      # Error should be displayed
      assert has_element?(view, ".alert-error")
    end

    test "create user with short password shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")

      view |> element("button", "+ Add User") |> render_click()

      view
      |> form("#create-user-form", %{
        "user" => %{
          "name" => "Test User",
          "email" => "test@example.com",
          "password" => "short",
        },
      })
      |> render_submit()

      # Form should still be visible
      assert has_element?(view, "#create-user-form")

      # Error should be displayed
      assert has_element?(view, ".alert-error")
    end
  end

  describe "users section - self protection" do
    setup :register_and_log_in_user

    test "no delete button shown for current user", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")

      # Should not have a delete button for the current user
      refute has_element?(view, ~s|button[phx-click="delete_user"][phx-value-id="#{user.id}"]|)
    end
  end

  # ============================================================================
  # Badges Section - Tests
  # ============================================================================

  describe "badges section - rendering" do
    setup :register_and_log_in_user

    test "displays page header", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, "h1", "Badges")
      assert has_element?(view, "p", "Manage attendee badges")
    end

    test "shows empty state when no badges exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, "p", "No badges yet")
    end

    test "lists existing badges in table", %{conn: conn} do
      badge = badge_fixture()

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, "td", badge.uid)
      assert has_element?(view, "td", badge.serial_key)
    end

    test "shows Import CSV button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, "button", "Import CSV")
    end

    test "shows search input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, "input[name=\"search\"]")
    end
  end

  describe "badges section - search" do
    setup :register_and_log_in_user

    test "search filters badges by UID with realtime debounced input", %{conn: conn} do
      badge1 = badge_fixture()
      _badge2 = badge_fixture()

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Both badges should be visible initially
      assert has_element?(view, "td", badge1.uid)

      # Search uses phx-change (realtime) instead of phx-submit
      view
      |> form("form[phx-change=\"search\"]", %{"search" => badge1.uid})
      |> render_change()

      # Only first badge should be visible
      assert has_element?(view, "td", badge1.uid)
    end
  end

  describe "badges section - toggle admin" do
    setup :register_and_log_in_user

    test "can make a regular badge an admin", %{conn: conn} do
      badge = badge_fixture()
      refute badge.is_admin

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Should have Make Admin button in dropdown menu
      view
      |> element(~s|button[phx-click="toggle_admin"][phx-value-id="#{badge.id}"]|, "Make Admin")
      |> render_click()

      # Should now show Admin badge
      assert has_element?(view, "span.badge-primary", "Admin")

      # Verify in database
      updated_badge = BadgesLogic.get_badge!(badge.id)
      assert updated_badge.is_admin
    end

    test "can revoke admin from an admin badge", %{conn: conn} do
      badge = admin_badge_fixture()
      assert badge.is_admin

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Should have Revoke Admin button in dropdown menu
      view
      |> element(~s|button[phx-click="toggle_admin"][phx-value-id="#{badge.id}"]|, "Revoke Admin")
      |> render_click()

      # Should no longer show Admin badge
      refute has_element?(view, ~s|tr:has(td:contains("#{badge.uid}")) span.badge-primary|, "Admin")

      # Verify in database
      updated_badge = BadgesLogic.get_badge!(badge.id)
      refute updated_badge.is_admin
    end
  end

  describe "badges section - toggle ban" do
    setup :register_and_log_in_user

    test "can ban a badge", %{conn: conn} do
      badge = badge_fixture()
      refute badge.is_banned

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> element(~s|button[phx-click="toggle_ban"][phx-value-id="#{badge.id}"]|, "Ban")
      |> render_click()

      assert has_element?(view, "span.badge-error", "Banned")

      updated_badge = BadgesLogic.get_badge!(badge.id)
      assert updated_badge.is_banned
    end

    test "can unban a banned badge", %{conn: conn} do
      {:ok, badge} = BadgesLogic.create_badge(%{uid: "BANNED-001", serial_key: "BANNED-001", is_banned: true})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> element(~s|button[phx-click="toggle_ban"][phx-value-id="#{badge.id}"]|, "Unban")
      |> render_click()

      refute has_element?(view, ~s|tr:has(td:contains("#{badge.uid}")) span.badge-error|, "Banned")

      updated_badge = BadgesLogic.get_badge!(badge.id)
      refute updated_badge.is_banned
    end
  end

  describe "badges section - delete" do
    setup :register_and_log_in_user

    test "can delete a badge via confirmation modal", %{conn: conn} do
      badge = badge_fixture()

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, "td", badge.uid)

      # Click delete to open confirmation modal
      view
      |> element(~s|button[phx-click="request_delete"][phx-value-id="#{badge.id}"]|, "Delete")
      |> render_click()

      # Modal should now be open with badge info
      assert has_element?(view, "dialog.modal-open")
      assert render(view) =~ badge.uid

      # Confirm deletion
      view
      |> element(~s|button[phx-click="confirm_delete"]|, "Delete Badge")
      |> render_click()

      # Badge should be gone
      refute has_element?(view, "td", badge.uid)
    end

    test "can cancel badge deletion", %{conn: conn} do
      badge = badge_fixture()

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, "td", badge.uid)

      # Click delete to open confirmation modal
      view
      |> element(~s|button[phx-click="request_delete"][phx-value-id="#{badge.id}"]|, "Delete")
      |> render_click()

      # Modal should be open
      assert has_element?(view, "dialog.modal-open")

      # Cancel deletion
      view
      |> element(~s|button[phx-click="cancel_delete"]|, "Cancel")
      |> render_click()

      # Modal should be closed, badge should still exist
      refute has_element?(view, "dialog.modal-open")
      assert has_element?(view, "td", badge.uid)
    end
  end

  describe "badges section - pagination" do
    setup :register_and_log_in_user

    test "shows pagination controls when badges exist", %{conn: conn} do
      badge_fixture()

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # DaisyUI join pagination uses « and » buttons
      assert has_element?(view, "button", "«")
      assert has_element?(view, "button", "»")
      # Also has go-to-page input
      assert has_element?(view, ~s|input[name="page"]|)
    end

    test "shows correct count", %{conn: conn} do
      for _ <- 1..3, do: badge_fixture()

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert render(view) =~ "3 total badges"
    end

    test "can navigate to specific page using go-to input", %{conn: conn} do
      # Create enough badges to have multiple pages (50 per page)
      for i <- 1..55, do: badge_fixture(%{uid: "PAGE-TEST-#{String.pad_leading(to_string(i), 3, "0")}"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Should be on page 1
      assert render(view) =~ "Showing 1-50 of 55"

      # Use go-to-page form to jump to page 2
      view
      |> form(~s|form[phx-submit="goto_page"]|, %{"page" => "2"})
      |> render_submit()

      # Should now show page 2
      assert render(view) =~ "Showing 51-55 of 55"
    end
  end
end
