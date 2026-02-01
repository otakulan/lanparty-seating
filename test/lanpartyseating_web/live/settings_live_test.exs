defmodule LanpartyseatingWeb.SettingsLiveTest do
  use LanpartyseatingWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lanpartyseating.AccountsFixtures
  import LanpartyseatingWeb.ConnCase

  alias Lanpartyseating.Repo
  alias Lanpartyseating.Setting

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
      assert has_element?(view, "h1", "Admin Badges")
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

      assert has_element?(view, "h1", "Admin Badges")
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
  # Badges Section - CRUD Tests
  # ============================================================================

  describe "badges section - rendering" do
    setup :register_and_log_in_user

    test "displays page header", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, "h1", "Admin Badges")
      assert has_element?(view, "p", "Manage admin badges for emergency backdoor access")
    end

    test "shows empty state when no badges exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, "p", "No badges configured")
    end

    test "lists existing badges in table", %{conn: conn} do
      badge = admin_badge_fixture(%{badge_number: "TEST-123", label: "Test Badge"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, "td", badge.badge_number)
      assert has_element?(view, "td", badge.label)
    end
  end

  describe "badges section - create form toggle" do
    setup :register_and_log_in_user

    test "form is hidden by default", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      refute has_element?(view, "#create-badge-form")
      assert has_element?(view, "button", "+ Add Badge")
    end

    test "clicking Add Badge shows form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element("button", "+ Add Badge") |> render_click()

      assert has_element?(view, "#create-badge-form")
      assert has_element?(view, ~s|input[name="badge[badge_number]"]|)
      assert has_element?(view, ~s|input[name="badge[label]"]|)
    end

    test "clicking Cancel hides form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element("button", "+ Add Badge") |> render_click()
      assert has_element?(view, "#create-badge-form")

      view |> element("button", "Cancel") |> render_click()
      refute has_element?(view, "#create-badge-form")
    end
  end

  describe "badges section - create badge" do
    setup :register_and_log_in_user

    test "create badge with valid params succeeds", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element("button", "+ Add Badge") |> render_click()

      view
      |> form("#create-badge-form", %{
        "badge" => %{
          "badge_number" => "NEW-BADGE-001",
          "label" => "New Test Badge",
        },
      })
      |> render_submit()

      # Form should be hidden after success
      refute has_element?(view, "#create-badge-form")

      # New badge should appear in table
      assert has_element?(view, "td", "NEW-BADGE-001")
      assert has_element?(view, "td", "New Test Badge")

      # Success flash
      assert render(view) =~ "Admin badge created successfully"
    end

    test "create badge with duplicate badge number shows error", %{conn: conn} do
      # Create an existing badge
      admin_badge_fixture(%{badge_number: "EXISTING-001"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element("button", "+ Add Badge") |> render_click()

      view
      |> form("#create-badge-form", %{
        "badge" => %{
          "badge_number" => "EXISTING-001",
          "label" => "Duplicate Badge",
        },
      })
      |> render_submit()

      # Form should still be visible
      assert has_element?(view, "#create-badge-form")

      # Error should be displayed
      assert has_element?(view, ".alert-error")
    end
  end

  describe "badges section - toggle enabled" do
    setup :register_and_log_in_user

    test "can disable an enabled badge", %{conn: conn} do
      badge = admin_badge_fixture(%{enabled: true})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Should show Enabled status and Disable button
      assert has_element?(view, "span.badge-success", "Enabled")

      view
      |> element(~s|button[phx-click="toggle_badge"][phx-value-id="#{badge.id}"]|, "Disable")
      |> render_click()

      # Should now show Disabled status
      assert has_element?(view, "span.badge-error", "Disabled")
      assert render(view) =~ "Badge disabled"
    end

    test "can enable a disabled badge", %{conn: conn} do
      badge = admin_badge_fixture(%{enabled: false})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Should show Disabled status and Enable button
      assert has_element?(view, "span.badge-error", "Disabled")

      view
      |> element(~s|button[phx-click="toggle_badge"][phx-value-id="#{badge.id}"]|, "Enable")
      |> render_click()

      # Should now show Enabled status
      assert has_element?(view, "span.badge-success", "Enabled")
      assert render(view) =~ "Badge enabled"
    end
  end
end
