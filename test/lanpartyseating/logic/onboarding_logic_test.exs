defmodule Lanpartyseating.OnboardingLogicTest do
  use Lanpartyseating.DataCase, async: false

  alias Lanpartyseating.Accounts
  alias Lanpartyseating.OnboardingLogic
  alias Lanpartyseating.Repo
  alias Lanpartyseating.SeatMapsLogic
  alias Lanpartyseating.Setting

  setup do
    Repo.get!(Setting, 1)
    |> Setting.changeset(%{setup_state: :not_started, active_room_id: nil})
    |> Repo.update!()

    :ok
  end

  defp set_state!(state) do
    Repo.get!(Setting, 1)
    |> Setting.changeset(%{setup_state: state, active_room_id: nil})
    |> Repo.update!()
  end

  defp create_account do
    {:ok, user} =
      OnboardingLogic.create_admin(
        %{
          name: "Operator",
          email: "operator@example.com",
          password: "a-very-long-password",
          password_confirmation: "a-very-long-password",
        }
      )

    user
  end

  defp create_room do
    {:ok, room} = OnboardingLogic.create_room(%{name: "My Hall"})
    room
  end

  defp imported_layout_json do
    Jason.encode!(
      %{
        width: 800,
        height: 600,
        meta: %{zoom: 1},
        seats:
          [
            %{
              seat_slot_id: nil,
              label: "A01",
              x: 10,
              y: 20,
              width: 60,
              height: 60,
              rotation: 0,
              shape: "rect",
              locked: false,
            },
          ],
        objects: [],
      }
    )
  end

  describe "state/0" do
    test "defaults to :not_started" do
      assert OnboardingLogic.state() == :not_started
      refute OnboardingLogic.complete?()
    end
  end

  describe "create_admin/1" do
    test "creates a confirmed admin account and advances the state" do
      assert {:ok, user} =
               OnboardingLogic.create_admin(
                 %{
                   name: "Operator",
                   email: "operator@example.com",
                   password: "a-very-long-password",
                   password_confirmation: "a-very-long-password",
                 }
               )

      assert user.confirmed_at != nil
      assert OnboardingLogic.state() == :admin_created
      assert Accounts.get_user_by_email("operator@example.com").id == user.id
    end

    test "refuses to run out of order" do
      set_state!(:admin_created)

      assert {:error, :wrong_state} =
               OnboardingLogic.create_admin(
                 %{
                   name: "Operator",
                   email: "operator@example.com",
                   password: "a-very-long-password",
                   password_confirmation: "a-very-long-password",
                 }
               )
    end
  end

  describe "create_room/1" do
    test "creates the room, activates it, and advances the state" do
      create_account()

      assert {:ok, room} = OnboardingLogic.create_room(%{name: "My Hall"})
      assert room.name == "My Hall"
      assert OnboardingLogic.state() == :room_created
      assert Repo.get!(Setting, 1).active_room_id == room.id
    end

    test "defaults to a random animal name when none is given" do
      create_account()

      assert {:ok, room} = OnboardingLogic.create_room(%{})
      assert room.name != ""
      assert room.name =~ "-"
    end

    test "refuses to run out of order" do
      assert {:error, :wrong_state} = OnboardingLogic.create_room(%{name: "Nope"})
    end
  end

  describe "publish_empty_layout/0" do
    test "publishes the active room's first map and advances to the settings step" do
      create_account()
      create_room()

      assert {:ok, _version} = OnboardingLogic.publish_empty_layout()
      assert OnboardingLogic.state() == :layout_ready
      assert {:ok, _payload} = SeatMapsLogic.get_map_payload()
    end
  end

  describe "import_layout/1" do
    test "imports a JSON layout, publishes it, and advances" do
      create_account()
      create_room()

      assert {:ok, _version} = OnboardingLogic.import_layout(%{"json" => imported_layout_json()})
      assert OnboardingLogic.state() == :layout_ready

      assert {:ok, payload} = SeatMapsLogic.get_map_payload()
      assert length(payload.seats) == 1
      assert hd(payload.seats).label == "A01"
      assert hd(payload.seats).shape == "rect"
    end

    test "rejects invalid JSON without advancing" do
      create_account()
      create_room()

      assert {:error, :invalid_json} = OnboardingLogic.import_layout(%{"json" => "not json"})
      assert OnboardingLogic.state() == :room_created
    end

    test "refuses to run out of order" do
      assert {:error, :wrong_state} = OnboardingLogic.import_layout(%{"json" => "{}"})
    end
  end

  describe "configure_settings/1" do
    test "writes the settings and completes onboarding" do
      create_account()
      create_room()
      OnboardingLogic.publish_empty_layout()

      assert {:ok, settings} =
               OnboardingLogic.configure_settings(
                 %{
                   reservation_duration_minutes: 50,
                   tournament_buffer_minutes: 30,
                   seat_picking_enabled_in_kiosk: true,
                 }
               )

      assert settings.setup_state == :complete
      assert OnboardingLogic.complete?()
      assert settings.reservation_duration_minutes == 50
      assert settings.tournament_buffer_minutes == 30
      assert settings.seat_picking_enabled_in_kiosk == true
    end

    test "rejects invalid settings without completing" do
      create_account()
      create_room()
      OnboardingLogic.publish_empty_layout()

      assert {:error, %Ecto.Changeset{}} =
               OnboardingLogic.configure_settings(%{reservation_duration_minutes: 1})

      assert OnboardingLogic.state() == :layout_ready
    end
  end
end
