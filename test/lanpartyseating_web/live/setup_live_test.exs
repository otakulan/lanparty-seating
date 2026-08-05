defmodule LanpartyseatingWeb.SetupLiveTest do
  use LanpartyseatingWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Lanpartyseating.OnboardingLogic
  alias Lanpartyseating.Repo
  alias Lanpartyseating.Setting

  defp set_setup_state!(state) do
    Repo.get!(Setting, 1)
    |> Setting.changeset(%{setup_state: state, active_room_id: nil})
    |> Repo.update!()
  end

  defp account_params do
    %{
      "name" => "Operator",
      "email" => "operator@example.com",
      "password" => "a-very-long-password",
      "password_confirmation" => "a-very-long-password",
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
      {:ok, view, _html} = live(conn, ~p"/setup")

      view
      |> form("#account-form", %{user: account_params()})
      |> render_submit()

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
      {:ok, view, _html} = live(conn, ~p"/setup")

      view
      |> form("#account-form", %{user: account_params()})
      |> render_submit()

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
      {:ok, view, _html} = live(conn, ~p"/setup")

      view
      |> form("#account-form", %{user: account_params()})
      |> render_submit()

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
  end
end
