defmodule LanpartyseatingWeb.SetupLiveTest do
  use LanpartyseatingWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Lanpartyseating.Accounts.User
  alias Lanpartyseating.OnboardingLogic
  alias Lanpartyseating.Repo
  alias Lanpartyseating.Room
  alias Lanpartyseating.Setting

  defp set_setup_state!(state) do
    Repo.get!(Setting, 1)
    |> Setting.changeset(%{setup_state: state, active_room_id: nil})
    |> Repo.update!()
  end

  defp account_params do
    %{
      "name" => "Operator",
      "email" => "operator+#{System.unique_integer()}@example.com",
      "password" => "a-very-long-password",
      "password_confirmation" => "a-very-long-password",
    }
  end

  defp short_params do
    %{
      "name" => "Operator",
      "email" => "operator+short+#{System.unique_integer()}@example.com",
      "password" => "short",
      "password_confirmation" => "short",
    }
  end

  defp imported_layout_json do
    Jason.encode!(
      %{
        width: 800,
        height: 600,
        meta: %{zoom: 1},
        seats:
          [
            %{seat_slot_id: nil, label: "A01", x: 10, y: 20, width: 60, height: 60, rotation: 0, shape: "rect", locked: false},
          ],
        objects: [],
      }
    )
  end

  # Account creation is a real HTTP POST to the controller (a LiveView cannot write the
  # session over the websocket), so drive it through the controller and follow the
  # redirect back into the wizard at the room step.
  #
  # `mix ecto.reset` seeds a Room (id=1) and the wizard creates another, so remove the
  # seeded one (and its dependents) to give the wizard a clean slate. This runs in the
  # test's sandboxed transaction.
  defp create_account(conn) do
    Repo.delete_all(Lanpartyseating.SeatMapVersion)
    Repo.delete_all(Lanpartyseating.SeatMap)
    Repo.delete_all(Lanpartyseating.SeatSlot)
    Repo.delete_all(Lanpartyseating.Room)

    conn
    |> post(~p"/setup/login", %{"user" => account_params()})
    |> redirected_to(302)
    |> then(&live(conn, &1))
  end

  describe "gate" do
    test "redirects to /settings when setup is complete", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/setup")
      assert path == ~p"/settings"
    end
  end

  describe "wizard" do
    setup %{conn: conn} do
      set_setup_state!(:not_started)
      {:ok, conn: conn}
    end

    test "shows the account step on a fresh install", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/setup")

      assert has_element?(view, "h1", "Get started")
      assert html =~ "Create your admin account"
      assert html =~ "Create account"
      assert has_element?(view, "#account-form")
    end

    test "walks the whole wizard to completion with an empty layout", %{conn: conn} do
      {:ok, view, _html} = create_account(conn)

      assert has_element?(view, "#room-form")

      view
      |> form("#room-form", %{room: %{"name" => "My Hall"}})
      |> render_submit()

      assert render(view) =~ "Publish empty layout"

      render_click(view, "finish_layout")

      assert has_element?(view, "#settings-form")

      view
      |> form(
        "#settings-form",
        %{
          settings: %{"reservation_duration_minutes" => "50", "tournament_buffer_minutes" => "30"},
        }
      )
      |> render_submit()

      assert has_element?(view, "h1", "You're all set!")
      assert has_element?(view, "a", "Add seats")
      assert has_element?(view, "a", "Go to settings")
      assert Repo.get!(Setting, 1).setup_state == :complete
    end

    test "imports a JSON layout on the layout step", %{conn: conn} do
      {:ok, view, _html} = create_account(conn)

      view
      |> form("#room-form", %{room: %{"name" => "My Hall"}})
      |> render_submit()

      render_click(view, "set_layout_choice", %{"choice" => "import"})
      render_change(view, "set_import_json", %{"json" => imported_layout_json()})
      render_click(view, "finish_layout")

      assert has_element?(view, "#settings-form")
      assert Repo.get!(Setting, 1).setup_state == :layout_ready
    end

    test "shows an error for invalid JSON and stays on the layout step", %{conn: conn} do
      {:ok, view, _html} = create_account(conn)

      view
      |> form("#room-form", %{room: %{"name" => "My Hall"}})
      |> render_submit()

      render_click(view, "set_layout_choice", %{"choice" => "import"})
      render_change(view, "set_import_json", %{"json" => "not json"})
      render_click(view, "finish_layout")

      assert render(view) =~ "Invalid JSON"
      assert has_element?(view, "textarea")
      assert Repo.get!(Setting, 1).setup_state == :room_created
    end

    test "resumes at the current step after a reload", %{conn: conn} do
      OnboardingLogic.create_admin(account_params())
      OnboardingLogic.create_room(%{name: "My Hall"})

      {:ok, view, _html} = live(conn, ~p"/setup")

      assert render(view) =~ "Publish empty layout"
      assert has_element?(view, "h1", "Get started")
    end

    test "completes on a freshly migrated database with no settings row", %{conn: conn} do
      Repo.delete_all(Setting)
      {:ok, _view, html} = live(conn, ~p"/setup")

      assert html =~ "Create your admin account"

      {:ok, view, _html} = create_account(conn)

      assert has_element?(view, "#room-form")

      view
      |> form("#room-form", %{room: %{"name" => "My Hall"}})
      |> render_submit()

      render_click(view, "finish_layout")

      view
      |> form(
        "#settings-form",
        %{
          settings: %{"reservation_duration_minutes" => "50", "tournament_buffer_minutes" => "30"},
        }
      )
      |> render_submit()

      assert has_element?(view, "h1", "You're all set!")
      assert Repo.get!(Setting, 1).setup_state == :complete
    end

    test "rejects a too-short password and keeps the operator on the account step", %{conn: conn} do
      conn = post(conn, ~p"/setup/login", %{"user" => short_params()})
      assert redirected_to(conn, 302) == ~p"/setup"

      {:ok, view, html} = live(conn, ~p"/setup")

      assert html =~ "Create your admin account"
      assert has_element?(view, "#account-form")
      assert Repo.aggregate(User, :count, :id) == 0
    end

    test "toggles between empty and import layout choices", %{conn: conn} do
      {:ok, view, _html} = create_account(conn)

      view
      |> form("#room-form", %{room: %{"name" => "My Hall"}})
      |> render_submit()

      assert render(view) =~ "Publish empty layout"
      refute render(view) =~ "Import &amp; publish"

      render_click(view, "set_layout_choice", %{"choice" => "import"})

      assert render(view) =~ "Import &amp; publish"
      assert has_element?(view, "textarea")
    end

    test "rejects non-map JSON on import and stays on the layout step", %{conn: conn} do
      {:ok, view, _html} = create_account(conn)

      view
      |> form("#room-form", %{room: %{"name" => "My Hall"}})
      |> render_submit()

      render_click(view, "set_layout_choice", %{"choice" => "import"})
      render_change(view, "set_import_json", %{"json" => "42"})
      render_click(view, "finish_layout")

      assert render(view) =~ "Invalid JSON"
      assert has_element?(view, "textarea")
      assert Repo.get!(Setting, 1).setup_state == :room_created
    end

    test "rejects a structurally invalid layout on import and stays on the layout step", %{conn: conn} do
      {:ok, view, _html} = create_account(conn)

      view
      |> form("#room-form", %{room: %{"name" => "My Hall"}})
      |> render_submit()

      render_click(view, "set_layout_choice", %{"choice" => "import"})
      render_change(view, "set_import_json", %{"json" => Jason.encode!(%{"seats" => %{}})})
      render_click(view, "finish_layout")

      assert render(view) =~ "Invalid layout JSON"
      assert has_element?(view, "textarea")
      assert Repo.get!(Setting, 1).setup_state == :room_created
    end

    test "persists the kiosk seat-picking toggle through completion", %{conn: conn} do
      {:ok, view, _html} = create_account(conn)

      view
      |> form("#room-form", %{room: %{"name" => "My Hall"}})
      |> render_submit()

      render_click(view, "finish_layout")

      view
      |> form(
        "#settings-form",
        %{
          settings:
            %{
              "reservation_duration_minutes" => "50",
              "tournament_buffer_minutes" => "30",
              "seat_picking_enabled_in_kiosk" => "true",
            },
        }
      )
      |> render_submit()

      assert has_element?(view, "h1", "You're all set!")
      assert Repo.get!(Setting, 1).seat_picking_enabled_in_kiosk == true
    end

    test "rejects out-of-range settings and stays on the settings step", %{conn: conn} do
      {:ok, view, _html} = create_account(conn)

      view
      |> form("#room-form", %{room: %{"name" => "My Hall"}})
      |> render_submit()

      render_click(view, "finish_layout")

      view
      |> form(
        "#settings-form",
        %{
          settings:
            %{
              "reservation_duration_minutes" => "1000",
              "tournament_buffer_minutes" => "30",
            },
        }
      )
      |> render_submit()

      assert has_element?(view, "#settings-form")
      assert Repo.get!(Setting, 1).setup_state == :layout_ready
    end

    test "links the completion screen to the room's seat map editor", %{conn: conn} do
      {:ok, view, _html} = create_account(conn)

      view
      |> form("#room-form", %{room: %{"name" => "My Hall"}})
      |> render_submit()

      render_click(view, "finish_layout")

      view
      |> form(
        "#settings-form",
        %{
          settings: %{"reservation_duration_minutes" => "50", "tournament_buffer_minutes" => "30"},
        }
      )
      |> render_submit()

      assert has_element?(view, "h1", "You're all set!")

      map_public_id =
        case OnboardingLogic.current_room_map() do
          {:ok, map} -> map.public_id
          _otherwise -> nil
        end

      assert has_element?(
               view,
               "a[href=\"/settings/seat-maps/#{map_public_id}/edit\"]",
               "Add seats"
             )
    end

    test "resumes at the room step after account creation and a reload", %{conn: conn} do
      rooms_before = Repo.aggregate(Room, :count, :id)
      OnboardingLogic.create_admin(account_params())
      {:ok, view, _html} = live(conn, ~p"/setup")

      assert render(view) =~ "1 of 4 steps completed"
      assert has_element?(view, "#room-form")
      assert Repo.aggregate(Room, :count, :id) == rooms_before
    end

    test "resumes at the layout step after room creation and a reload", %{conn: conn} do
      OnboardingLogic.create_admin(account_params())
      OnboardingLogic.create_room(%{name: "My Hall"})
      {:ok, view, _html} = live(conn, ~p"/setup")

      assert render(view) =~ "2 of 4 steps completed"
      assert render(view) =~ "Publish empty layout"
      assert has_element?(view, "h1", "Get started")
    end
  end
end
