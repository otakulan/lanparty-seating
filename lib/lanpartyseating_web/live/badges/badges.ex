defmodule LanpartyseatingWeb.BadgesControllerLive do
  use Phoenix.LiveView
  alias Lanpartyseating.SeatingLogic, as: SeatingLogic

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      Phoenix.View.render(LanpartyseatingWeb.BadgesView, "badges.html", assigns)
    end

    def handle_event("submit_reservation", %{"badge_number" => badge_number}, socket) do
      IO.inspect(label: "******** submit_reservation entered")
      assigned_station_id = SeatingLogic.register_seat(badge_number)
      IO.inspect(label: "******** SeatingLogic.register_seat called")
      IO.inspect(label: "******** assigned id: " <> assigned_station_id)

      # ??? is this
      #stations = StationLogic.get_all_stations()
      #broadcast_stations(stations)

      ## TODO: Display the ID of the reserved seat, all station have a username and password that relates to their ID
      ## The ID is the one of the next available station. People who come in group should scan their
      ## badge one after another if they want to be togheter.

      {:noreply, socket}
    end

  end
