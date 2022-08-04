defmodule LanpartyseatingWeb.TournamentsControllerLive do
use Phoenix.LiveView
  alias Lanpartyseating.TournamentsLogic, as: TournamentsLogic

  def mount(_params, _session, socket) do
    tournaments = TournamentsLogic.get_all_tournaments()

    socket = socket
    |> assign(:tournaments, tournaments)
    |> assign(:tournamentsCount, length(tournaments))

    {:ok, socket}
  end

  def render(assigns) do
    Phoenix.View.render(LanpartyseatingWeb.TournamentsView, "tournaments.html", assigns)
  end

end
