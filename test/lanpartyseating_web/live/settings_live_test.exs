defmodule LanpartyseatingWeb.SettingsLiveTest do
  use LanpartyseatingWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LanpartyseatingWeb.ConnCase

  # ============================================================================
  # Authentication/Authorization Tests
  # ============================================================================

  describe "unauthenticated access" do
    test "redirects from /settings to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "redirects from /settings/seat-maps to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings/seat-maps")
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
    setup [:register_and_log_in_user]

    test "/settings opens general settings", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")
      assert has_element?(view, "h1", "General")
    end

    test "can access /settings/seat-maps", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")
      assert has_element?(view, "h1", "Seat Maps")
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
    setup [:register_and_log_in_badge]

    test "can access /settings/seat-maps", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")
      assert has_element?(view, "h1", "Seat Maps")
    end

    test "redirected from /settings/users with error flash", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: path, flash: flash}}} = live(conn, ~p"/settings/users")
      assert path == ~p"/settings"
      assert flash["error"] == "Full admin access required"
    end

    test "redirected from /settings/badges with error flash", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: path, flash: flash}}} = live(conn, ~p"/settings/badges")
      assert path == ~p"/settings"
      assert flash["error"] == "Full admin access required"
    end
  end

  # ============================================================================
  # Sidebar Rendering Tests
  # ============================================================================

  describe "sidebar - user auth" do
    setup [:register_and_log_in_user]

    test "shows all menu items", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      # Use the drawer-side menu specifically
      assert has_element?(view, ".drawer-side a[href=\"/settings/seat-maps\"]", "Seat Maps")
      assert has_element?(view, ".drawer-side a[href=\"/settings/users\"]", "Users")
      assert has_element?(view, ".drawer-side a[href=\"/settings/badges\"]", "Badges")
    end

    test "seat map link is active on seat map page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")
      assert has_element?(view, ~s|.drawer-side a[href="/settings/seat-maps"].active|)
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
    setup [:register_and_log_in_badge]

    test "shows only seating link, not users or badges", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      assert has_element?(view, ~s|.drawer-side a[href="/settings/seat-maps"]|, "Seat Maps")
      refute has_element?(view, ~s|.drawer-side a[href="/settings/users"]|)
      refute has_element?(view, ~s|.drawer-side a[href="/settings/badges"]|)
    end
  end

  describe "sidebar navigation" do
    setup [:register_and_log_in_user]

    test "clicking Users link navigates to /settings/users", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      {:ok, view, _html} =
        view
        |> element(~s|.drawer-side a[href="/settings/users"]|)
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(view, "h1", "Admin Users")
    end

    test "clicking Badges link navigates to /settings/badges", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      {:ok, view, _html} =
        view
        |> element(~s|.drawer-side a[href="/settings/badges"]|)
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(view, "h1", "Badges")
    end

    test "clicking Seat Map link navigates to /settings/seat-maps", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/users")

      {:ok, view, _html} =
        view
        |> element(~s|.drawer-side a[href="/settings/seat-maps"]|)
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(view, "h1", "Seat Maps")
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
      |> form(
        "#create-user-form",
        %{
          "user" => %{
            "name" => "New Test User",
            "email" => "newuser@example.com",
            "password" => "validpassword123",
          },
        }
      )
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
      |> form(
        "#create-user-form",
        %{
          "user" => %{
            "name" => "Test User",
            "email" => "not-an-email",
            "password" => "validpassword123",
          },
        }
      )
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
      |> form(
        "#create-user-form",
        %{
          "user" => %{
            "name" => "Test User",
            "email" => "test@example.com",
            "password" => "short",
          },
        }
      )
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

  # Note: Badge-specific tests (CRUD, search, pagination, admin/ban toggles, CSV import)
  # are in test/lanpartyseating_web/live/settings/badges_live_test.exs
  # This file focuses on cross-page concerns: auth, sidebar, navigation, and users section.
end
