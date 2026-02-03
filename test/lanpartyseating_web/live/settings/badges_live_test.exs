defmodule LanpartyseatingWeb.Settings.BadgesLiveTest do
  use LanpartyseatingWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lanpartyseating.AccountsFixtures
  import LanpartyseatingWeb.ConnCase

  alias Lanpartyseating.BadgesLogic

  # ============================================================================
  # Authentication Tests
  # ============================================================================

  describe "authentication" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings/badges")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "accessible with user auth", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture())
      {:ok, view, _html} = live(conn, ~p"/settings/badges")
      assert has_element?(view, "h1", "Badges")
    end

    test "redirects badge auth users to seating settings", %{conn: conn} do
      conn = conn |> log_in_badge(admin_badge_fixture())

      assert {:error, {:live_redirect, %{to: "/settings/seating", flash: flash}}} =
               live(conn, ~p"/settings/badges")

      assert flash["error"] == "Full admin access required"
    end
  end

  # ============================================================================
  # Sidebar Tests
  # ============================================================================

  describe "sidebar" do
    setup :register_and_log_in_user

    test "shows Badges link in sidebar", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")
      assert has_element?(view, ~s|.drawer-side a[href="/settings/badges"]|, "Badges")
    end

    test "Badges link is active on badges page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")
      assert has_element?(view, ~s|.drawer-side a[href="/settings/badges"].active|)
    end
  end

  # ============================================================================
  # Empty State Tests
  # ============================================================================

  describe "empty states" do
    setup :register_and_log_in_user

    test "shows empty message when no badges exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")
      assert render(view) =~ "No badges yet. Import a CSV to get started."
    end

    test "shows empty search result message when no matches", %{conn: conn} do
      badge_fixture(%{uid: "BADGE001", serial_key: "001"})
      {:ok, view, _html} = live(conn, ~p"/settings/badges?search=NONEXISTENT")
      # The quote is rendered as HTML entity in the template
      assert render(view) =~ "No badges found matching"
      assert render(view) =~ "NONEXISTENT"
    end

    test "shows total badge count in header", %{conn: conn} do
      badge_fixture(%{uid: "BADGE001", serial_key: "001"})
      badge_fixture(%{uid: "BADGE002", serial_key: "002"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")
      assert render(view) =~ "2 total badges"
    end
  end

  # ============================================================================
  # Badge Listing Tests
  # ============================================================================

  describe "badge listing" do
    setup :register_and_log_in_user

    test "displays badges in table", %{conn: conn} do
      badge_fixture(%{uid: "TESTUID123", serial_key: "SN001"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert render(view) =~ "TESTUID123"
      assert render(view) =~ "SN001"
    end

    test "displays badge status badges", %{conn: conn} do
      badge_fixture(%{uid: "NORMAL", serial_key: "001", is_admin: false, is_banned: false})
      badge_fixture(%{uid: "ADMIN", serial_key: "002", is_admin: true, is_banned: false})
      badge_fixture(%{uid: "BANNED", serial_key: "003", is_admin: false, is_banned: true})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Check for status badges
      assert has_element?(view, ".badge-ghost", "Normal")
      assert has_element?(view, ".badge-primary", "Admin")
      assert has_element?(view, ".badge-error", "Banned")
    end

    # Note: Admin and Banned cannot both be true (database constraint)
    # This is enforced by the admin_cannot_be_banned check constraint
  end

  # ============================================================================
  # Search Tests
  # ============================================================================

  describe "search" do
    setup :register_and_log_in_user

    test "filters by UID", %{conn: conn} do
      badge_fixture(%{uid: "SEARCHME123", serial_key: "001"})
      badge_fixture(%{uid: "OTHERBADGE", serial_key: "002"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> form(~s|form[phx-change="search"]|, %{"search" => "SEARCHME"})
      |> render_change()

      # Wait for debounce by pushing patch
      assert_patch(view, ~p"/settings/badges?search=SEARCHME&page=1")

      html = render(view)
      assert html =~ "SEARCHME123"
      refute html =~ "OTHERBADGE"
    end

    test "filters by serial key", %{conn: conn} do
      badge_fixture(%{uid: "BADGE001", serial_key: "FINDTHIS"})
      badge_fixture(%{uid: "BADGE002", serial_key: "NOTTHIS"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges?search=FINDTHIS")

      html = render(view)
      assert html =~ "BADGE001"
      refute html =~ "BADGE002"
    end

    test "clear button removes search filter", %{conn: conn} do
      badge_fixture(%{uid: "BADGE001", serial_key: "001"})
      badge_fixture(%{uid: "BADGE002", serial_key: "002"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges?search=BADGE001")

      # Click clear link - this navigates so we follow the redirect
      assert has_element?(view, ~s|a[href="/settings/badges"]|, "Clear")

      {:ok, view, _html} =
        view
        |> element(~s|a[href="/settings/badges"]|, "Clear")
        |> render_click()
        |> follow_redirect(conn)

      html = render(view)
      assert html =~ "BADGE001"
      assert html =~ "BADGE002"
    end

    test "search resets to page 1", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges?page=5")

      view
      |> form(~s|form[phx-change="search"]|, %{"search" => "test"})
      |> render_change()

      assert_patch(view, ~p"/settings/badges?search=test&page=1")
    end
  end

  # ============================================================================
  # Pagination Tests
  # ============================================================================

  describe "pagination" do
    setup :register_and_log_in_user

    setup do
      # Create 55 badges to test pagination (50 per page)
      for i <- 1..55 do
        badge_fixture(%{uid: "BADGE#{String.pad_leading("#{i}", 3, "0")}", serial_key: "#{i}"})
      end

      :ok
    end

    test "shows first page by default", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert render(view) =~ "Showing 1-50 of 55"
      assert has_element?(view, "button.btn-active", "1")
    end

    test "navigates to next page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="next_page"]|) |> render_click()
      assert_patch(view, ~p"/settings/badges?search=&page=2")

      assert render(view) =~ "Showing 51-55 of 55"
    end

    test "navigates to previous page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges?page=2")

      view |> element(~s|button[phx-click="prev_page"]|) |> render_click()
      assert_patch(view, ~p"/settings/badges?search=&page=1")
    end

    test "prev button disabled on first page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, ~s|button[phx-click="prev_page"][disabled]|)
    end

    test "next button disabled on last page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges?page=2")

      assert has_element?(view, ~s|button[phx-click="next_page"][disabled]|)
    end

    test "goto_page navigates to specific page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> form(~s|form[phx-submit="goto_page"]|, %{"page" => "2"})
      |> render_submit()

      assert_patch(view, ~p"/settings/badges?search=&page=2")
    end

    test "goto_page ignores invalid page numbers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> element(~s|button[phx-click="goto_page"][phx-value-page="1"]|)
      |> render_click()

      # Should stay on page 1
      assert render(view) =~ "Showing 1-50 of 55"
    end
  end

  # ============================================================================
  # Add Badge Tests
  # ============================================================================

  describe "add badge" do
    setup :register_and_log_in_user

    test "shows add badge button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, "button", "Add Badge")
    end

    test "opens add badge modal when button clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="show_add_badge_modal"]|) |> render_click()

      assert has_element?(view, "dialog.modal-open")
      assert has_element?(view, "h3", "Add Badge")
    end

    test "creates badge with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="show_add_badge_modal"]|) |> render_click()

      view
      |> form(~s|form[phx-submit="create_badge"]|, %{"uid" => "NEWBADGE123", "serial_key" => "SN999"})
      |> render_submit()

      # Modal should close and badge should appear
      refute has_element?(view, "dialog.modal-open h3", "Add Badge")
      assert render(view) =~ "Badge created successfully"
      assert render(view) =~ "NEWBADGE123"
      assert render(view) =~ "SN999"
    end

    test "shows error for duplicate UID", %{conn: conn} do
      badge_fixture(%{uid: "EXISTING123", serial_key: "001"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="show_add_badge_modal"]|) |> render_click()

      view
      |> form(~s|form[phx-submit="create_badge"]|, %{"uid" => "EXISTING123", "serial_key" => "002"})
      |> render_submit()

      assert render(view) =~ "Failed to create badge"
    end

    test "cancels add badge modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="show_add_badge_modal"]|) |> render_click()
      assert has_element?(view, "dialog.modal-open")

      # Use the Cancel button inside the modal (not the backdrop button)
      view |> element(~s|button[type="button"][phx-click="cancel_add_badge"]|) |> render_click()
      refute has_element?(view, "dialog.modal-open h3", "Add Badge")
    end
  end

  # ============================================================================
  # Toggle Admin Tests
  # ============================================================================

  describe "toggle admin" do
    setup :register_and_log_in_user

    test "makes badge admin", %{conn: conn} do
      badge = badge_fixture(%{uid: "NORMALUSER", serial_key: "001", is_admin: false})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Initially shows Normal status
      refute has_element?(view, ".badge-primary", "Admin")

      view
      |> element(~s|button[phx-click="toggle_admin"][phx-value-id="#{badge.id}"]|)
      |> render_click()

      # Now shows Admin
      assert has_element?(view, ".badge-primary", "Admin")

      # Verify in database
      updated = BadgesLogic.get_badge!(badge.id)
      assert updated.is_admin
    end

    test "revokes admin", %{conn: conn} do
      badge = badge_fixture(%{uid: "ADMINUSER", serial_key: "001", is_admin: true})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> element(~s|button[phx-click="toggle_admin"][phx-value-id="#{badge.id}"]|)
      |> render_click()

      # Verify admin was revoked
      updated = BadgesLogic.get_badge!(badge.id)
      refute updated.is_admin
    end
  end

  # ============================================================================
  # Toggle Ban Tests
  # ============================================================================

  describe "toggle ban" do
    setup :register_and_log_in_user

    test "bans badge", %{conn: conn} do
      badge = badge_fixture(%{uid: "TOBEBANNED", serial_key: "001", is_banned: false})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> element(~s|button[phx-click="toggle_ban"][phx-value-id="#{badge.id}"]|)
      |> render_click()

      assert has_element?(view, ".badge-error", "Banned")

      updated = BadgesLogic.get_badge!(badge.id)
      assert updated.is_banned
    end

    test "unbans badge", %{conn: conn} do
      badge = badge_fixture(%{uid: "BANNEDUSER", serial_key: "001", is_banned: true})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> element(~s|button[phx-click="toggle_ban"][phx-value-id="#{badge.id}"]|)
      |> render_click()

      updated = BadgesLogic.get_badge!(badge.id)
      refute updated.is_banned
    end
  end

  # ============================================================================
  # Delete Badge Tests
  # ============================================================================

  describe "delete badge" do
    setup :register_and_log_in_user

    test "opens delete confirmation modal", %{conn: conn} do
      badge = badge_fixture(%{uid: "TODELETE", serial_key: "001"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> element(~s|button[phx-click="request_delete"][phx-value-id="#{badge.id}"]|)
      |> render_click()

      assert has_element?(view, "dialog.modal-open")
      assert has_element?(view, "h3", "Delete Badge")
      assert render(view) =~ "TODELETE"
    end

    test "confirms and deletes badge", %{conn: conn} do
      badge = badge_fixture(%{uid: "WILLDISAPPEAR", serial_key: "001"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> element(~s|button[phx-click="request_delete"][phx-value-id="#{badge.id}"]|)
      |> render_click()

      view |> element(~s|button[phx-click="confirm_delete"]|) |> render_click()

      # Modal closes and badge is gone
      refute has_element?(view, "dialog.modal-open")
      refute render(view) =~ "WILLDISAPPEAR"

      # Verify deleted in database
      assert_raise Ecto.NoResultsError, fn ->
        BadgesLogic.get_badge!(badge.id)
      end
    end

    test "cancels delete", %{conn: conn} do
      badge = badge_fixture(%{uid: "STAYSAFE", serial_key: "001"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> element(~s|button[phx-click="request_delete"][phx-value-id="#{badge.id}"]|)
      |> render_click()

      # Use the Cancel button inside the modal (has class="btn")
      view |> element(~s|button.btn[phx-click="cancel_delete"]|) |> render_click()

      refute has_element?(view, "dialog.modal-open")
      assert render(view) =~ "STAYSAFE"

      # Badge still exists
      assert BadgesLogic.get_badge!(badge.id)
    end

    test "shows badge details in delete modal", %{conn: conn} do
      badge = badge_fixture(%{uid: "DETAILED", serial_key: "001", is_admin: true, label: "VIP Badge"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> element(~s|button[phx-click="request_delete"][phx-value-id="#{badge.id}"]|)
      |> render_click()

      html = render(view)
      assert html =~ "DETAILED"
      assert html =~ "VIP Badge"
      assert html =~ "Admin"
    end
  end

  # ============================================================================
  # Inline Label Editing Tests
  # ============================================================================

  describe "inline label editing" do
    setup :register_and_log_in_user

    test "displays existing label", %{conn: conn} do
      badge_fixture(%{uid: "LABELED", serial_key: "001", label: "Staff Badge"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, ~s|input[value="Staff Badge"]|)
    end

    test "saves new label", %{conn: conn} do
      badge = badge_fixture(%{uid: "UNLABELED", serial_key: "001", label: nil})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> form(~s|form[phx-submit="save_label"]|, %{"badge_id" => badge.id, "label" => "New Label"})
      |> render_submit()

      updated = BadgesLogic.get_badge!(badge.id)
      assert updated.label == "New Label"
    end

    test "clears label when empty", %{conn: conn} do
      badge = badge_fixture(%{uid: "HASLABEL", serial_key: "001", label: "Old Label"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view
      |> form(~s|form[phx-submit="save_label"]|, %{"badge_id" => badge.id, "label" => ""})
      |> render_submit()

      updated = BadgesLogic.get_badge!(badge.id)
      assert updated.label == nil
    end
  end

  # ============================================================================
  # CSV Import Modal Tests
  # ============================================================================

  describe "CSV import modal" do
    setup :register_and_log_in_user

    test "shows import CSV button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      assert has_element?(view, "button", "Import CSV")
    end

    test "opens import modal when button clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="open_import_modal"]|) |> render_click()

      assert has_element?(view, "dialog.modal-open")
      assert has_element?(view, "h3", "Import Badges from CSV")
    end

    test "closes import modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="open_import_modal"]|) |> render_click()
      assert has_element?(view, "dialog.modal-open")

      view |> element(~s|button[phx-click="close_import_modal"]|) |> render_click()
      refute has_element?(view, "dialog.modal-open")
    end

    test "shows warning about replacing all badges", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="open_import_modal"]|) |> render_click()

      assert render(view) =~ "Import will replace ALL existing badges"
    end

    test "shows file input for CSV upload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="open_import_modal"]|) |> render_click()

      assert has_element?(view, ~s|input[type="file"]|)
      assert has_element?(view, "button", "Preview Import")
    end

    test "previews valid CSV file", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="open_import_modal"]|) |> render_click()

      csv_path = Path.join([__DIR__, "../../../support/fixtures/files/valid_badges.csv"])

      # Upload the CSV file
      csv_content = File.read!(csv_path)

      view
      |> file_input(~s|form[phx-submit="preview_csv"]|, :csv_file, [
        %{
          name: "badges.csv",
          content: csv_content,
          type: "text/csv",
        },
      ])
      |> render_upload("badges.csv")

      # Submit preview
      view
      |> form(~s|form[phx-submit="preview_csv"]|)
      |> render_submit()

      # Should show preview with row count
      html = render(view)
      assert html =~ "Ready to import"
      assert html =~ "3 rows"
      # Should show sample data
      assert html =~ "BADGE001"
      assert html =~ "001"
    end

    test "imports CSV and replaces all badges", %{conn: conn} do
      # Create existing badges that should be replaced
      badge_fixture(%{uid: "EXISTING1", serial_key: "E001"})
      badge_fixture(%{uid: "EXISTING2", serial_key: "E002"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Verify existing badges are shown
      assert render(view) =~ "EXISTING1"

      view |> element(~s|button[phx-click="open_import_modal"]|) |> render_click()

      csv_path = Path.join([__DIR__, "../../../support/fixtures/files/valid_badges.csv"])
      csv_content = File.read!(csv_path)

      view
      |> file_input(~s|form[phx-submit="preview_csv"]|, :csv_file, [
        %{
          name: "badges.csv",
          content: csv_content,
          type: "text/csv",
        },
      ])
      |> render_upload("badges.csv")

      view
      |> form(~s|form[phx-submit="preview_csv"]|)
      |> render_submit()

      # Confirm import - this triggers send(self(), :do_import)
      view |> element(~s|button[phx-click="confirm_import"]|) |> render_click()

      # render() processes the :do_import message from the mailbox
      html = render(view)

      # Should show success message
      assert html =~ "Successfully imported 3 badges"

      # Old badges should be gone, new ones present
      refute html =~ "EXISTING1"
      refute html =~ "EXISTING2"
      assert html =~ "BADGE001"
      assert html =~ "BADGE002"
      assert html =~ "BADGE003"
    end

    test "shows error for invalid CSV format", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="open_import_modal"]|) |> render_click()

      csv_path = Path.join([__DIR__, "../../../support/fixtures/files/invalid_badges.csv"])
      csv_content = File.read!(csv_path)

      view
      |> file_input(~s|form[phx-submit="preview_csv"]|, :csv_file, [
        %{
          name: "invalid.csv",
          content: csv_content,
          type: "text/csv",
        },
      ])
      |> render_upload("invalid.csv")

      view
      |> form(~s|form[phx-submit="preview_csv"]|)
      |> render_submit()

      # Should show error
      assert render(view) =~ "must have at least two columns"
    end

    test "rejects CSV with invalid row data at preview time", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="open_import_modal"]|) |> render_click()

      csv_path = Path.join([__DIR__, "../../../support/fixtures/files/invalid_empty_uid.csv"])
      csv_content = File.read!(csv_path)

      view
      |> file_input(~s|form[phx-submit="preview_csv"]|, :csv_file, [
        %{
          name: "invalid.csv",
          content: csv_content,
          type: "text/csv",
        },
      ])
      |> render_upload("invalid.csv")

      view
      |> form(~s|form[phx-submit="preview_csv"]|)
      |> render_submit()

      # Error should appear at preview time (validation happens during preview)
      html = render(view)
      assert html =~ "Row 3"
      assert html =~ "uid"
    end

    test "rejects CSV with row missing columns at preview time", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="open_import_modal"]|) |> render_click()

      csv_path = Path.join([__DIR__, "../../../support/fixtures/files/missing_column.csv"])
      csv_content = File.read!(csv_path)

      view
      |> file_input(~s|form[phx-submit="preview_csv"]|, :csv_file, [
        %{
          name: "missing.csv",
          content: csv_content,
          type: "text/csv",
        },
      ])
      |> render_upload("missing.csv")

      view
      |> form(~s|form[phx-submit="preview_csv"]|)
      |> render_submit()

      # Error should appear at preview time
      html = render(view)
      assert html =~ "Row 3"
      assert html =~ "must have at least two columns"
    end
  end

  # ============================================================================
  # Invalid Page Parameter Tests
  # ============================================================================

  describe "invalid page parameter" do
    setup :register_and_log_in_user

    test "non-numeric page parameter defaults to page 1", %{conn: conn} do
      badge_fixture(%{uid: "BADGE001", serial_key: "001"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges?page=abc")

      # Should default to page 1, not crash
      assert render(view) =~ "BADGE001"
      assert has_element?(view, "button.btn-active", "1")
    end

    test "negative page parameter defaults to page 1", %{conn: conn} do
      badge_fixture(%{uid: "BADGE001", serial_key: "001"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges?page=-5")

      # Should default to page 1
      assert has_element?(view, "button.btn-active", "1")
    end

    test "zero page parameter defaults to page 1", %{conn: conn} do
      badge_fixture(%{uid: "BADGE001", serial_key: "001"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges?page=0")

      # Should default to page 1
      assert has_element?(view, "button.btn-active", "1")
    end
  end

  # ============================================================================
  # Admin Cannot Be Banned Tests
  # ============================================================================

  describe "admin cannot be banned constraint" do
    setup :register_and_log_in_user

    test "hides 'Make Admin' button for banned badges", %{conn: conn} do
      banned = badge_fixture(%{uid: "BANNED", serial_key: "001", is_banned: true, is_admin: false})
      normal = badge_fixture(%{uid: "NORMAL", serial_key: "002", is_banned: false, is_admin: false})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Normal badge should have Make Admin button
      assert has_element?(
               view,
               ~s|ul#badge-menu-#{normal.id} button[phx-click="toggle_admin"]|,
               "Make Admin"
             )

      # Banned badge should NOT have Make Admin button
      refute has_element?(
               view,
               ~s|ul#badge-menu-#{banned.id} button[phx-click="toggle_admin"]|,
               "Make Admin"
             )
    end

    test "shows 'Revoke Admin' button for admin badges", %{conn: conn} do
      admin = badge_fixture(%{uid: "ADMIN", serial_key: "001", is_admin: true})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Admin badge should have Revoke Admin button
      assert has_element?(
               view,
               ~s|ul#badge-menu-#{admin.id} button[phx-click="toggle_admin"]|,
               "Revoke Admin"
             )
    end

    test "hides 'Ban' button for admin badges", %{conn: conn} do
      admin = badge_fixture(%{uid: "ADMIN", serial_key: "001", is_admin: true})
      normal = badge_fixture(%{uid: "NORMAL", serial_key: "002", is_admin: false})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Normal badge should have Ban button
      assert has_element?(
               view,
               ~s|ul#badge-menu-#{normal.id} button[phx-click="toggle_ban"]|,
               "Ban"
             )

      # Admin badge should NOT have Ban button
      refute has_element?(
               view,
               ~s|ul#badge-menu-#{admin.id} button[phx-click="toggle_ban"]|
             )
    end

    test "shows 'Unban' button for banned badges", %{conn: conn} do
      banned = badge_fixture(%{uid: "BANNED", serial_key: "001", is_banned: true})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Banned badge should have Unban button
      assert has_element?(
               view,
               ~s|ul#badge-menu-#{banned.id} button[phx-click="toggle_ban"]|,
               "Unban"
             )
    end

    test "toggle_admin fails with flash error for banned badge", %{conn: conn} do
      banned = badge_fixture(%{uid: "BANNED", serial_key: "001", is_banned: true, is_admin: false})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Manually trigger the event (would require bypass of UI hiding)
      render_click(view, "toggle_admin", %{"id" => to_string(banned.id)})

      # Should show error flash
      assert render(view) =~ "Cannot make a banned badge an admin"

      # Badge should still be banned, not admin
      updated = BadgesLogic.get_badge!(banned.id)
      refute updated.is_admin
      assert updated.is_banned
    end

    test "toggle_ban fails with flash error for admin badge", %{conn: conn} do
      admin = badge_fixture(%{uid: "ADMIN", serial_key: "001", is_admin: true, is_banned: false})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # Manually trigger the event (would require bypass of UI hiding)
      render_click(view, "toggle_ban", %{"id" => to_string(admin.id)})

      # Should show error flash
      assert render(view) =~ "Cannot ban an admin badge"

      # Badge should still be admin, not banned
      updated = BadgesLogic.get_badge!(admin.id)
      assert updated.is_admin
      refute updated.is_banned
    end

    test "can unban a badge then make it admin", %{conn: conn} do
      badge = badge_fixture(%{uid: "TOBEUNADMIN", serial_key: "001", is_banned: true, is_admin: false})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # First unban
      render_click(view, "toggle_ban", %{"id" => to_string(badge.id)})

      # Now make admin should work
      render_click(view, "toggle_admin", %{"id" => to_string(badge.id)})

      updated = BadgesLogic.get_badge!(badge.id)
      assert updated.is_admin
      refute updated.is_banned
    end

    test "can revoke admin then ban", %{conn: conn} do
      badge = badge_fixture(%{uid: "TOBEREVOKEDBAN", serial_key: "001", is_admin: true, is_banned: false})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      # First revoke admin
      render_click(view, "toggle_admin", %{"id" => to_string(badge.id)})

      # Now ban should work
      render_click(view, "toggle_ban", %{"id" => to_string(badge.id)})

      updated = BadgesLogic.get_badge!(badge.id)
      refute updated.is_admin
      assert updated.is_banned
    end
  end

  # ============================================================================
  # Add Badge Validation Tests
  # ============================================================================

  describe "add badge validation" do
    setup :register_and_log_in_user

    test "shows specific error for duplicate UID", %{conn: conn} do
      badge_fixture(%{uid: "DUPLICATE123", serial_key: "001"})

      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="show_add_badge_modal"]|) |> render_click()

      view
      |> form(~s|form[phx-submit="create_badge"]|, %{"uid" => "DUPLICATE123", "serial_key" => "002"})
      |> render_submit()

      html = render(view)
      assert html =~ "Failed to create badge"
      assert html =~ "uid"
    end

    test "shows error for empty UID", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="show_add_badge_modal"]|) |> render_click()

      view
      |> form(~s|form[phx-submit="create_badge"]|, %{"uid" => "", "serial_key" => "001"})
      |> render_submit()

      html = render(view)
      assert html =~ "Failed to create badge"
      assert html =~ "uid"
    end

    test "shows error for empty serial key", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/badges")

      view |> element(~s|button[phx-click="show_add_badge_modal"]|) |> render_click()

      view
      |> form(~s|form[phx-submit="create_badge"]|, %{"uid" => "NEWBADGE", "serial_key" => ""})
      |> render_submit()

      html = render(view)
      assert html =~ "Failed to create badge"
      assert html =~ "serial_key"
    end
  end
end
