defmodule LanpartyseatingWeb.DisplayControllerLive do
use Phoenix.LiveView

  def mount(_params, _session, socket) do
    stations = Lanpartyseating.StationLogic.get_all_stations()
    socket = socket
    |> assign(:columns, 10)
    |> assign(:rows, 4)
    |> assign(:col_trailing, 0)
    |> assign(:row_trailing, 0)
    |> assign(:colpad, 1)
    |> assign(:rowpad, 1)
    |> assign(:table, Enum.to_list(1..length(stations)))
    {:ok, socket}
  end

  def render(assigns) do
    Phoenix.View.render(LanpartyseatingWeb.DisplayView, "display.html", assigns)
  end

end
