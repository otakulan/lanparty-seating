defmodule LanpartyseatingWeb.DisplayControllerLive do
use Phoenix.LiveView
alias Lanpartyseating.PubSub, as: PubSub

  def mount(_params, _session, socket) do
    settings = Lanpartyseating.SettingsLogic.get_settings()

    Phoenix.PubSub.subscribe(PubSub, "update_stations")

    socket = socket
    |> assign(:columns, settings.columns)
    |> assign(:rows, settings.rows)
    |> assign(:col_trailing, settings.vertical_trailing)
    |> assign(:row_trailing, settings.horizontal_trailing)
    |> assign(:colpad, settings.column_padding)
    |> assign(:rowpad, settings.row_padding)
    |> assign(:stations, Lanpartyseating.StationLogic.get_all_stations())

    {:ok, socket}
  end

  def render(assigns) do
    Phoenix.PubSub.subscribe(PubSub, "update_stations")

    Phoenix.View.render(LanpartyseatingWeb.DisplayView, "display.html", assigns)
  end

  def handle_info({:update_stations, stations}, socket) do
    {:noreply, assign(socket, :stations, stations)}
  end

end
