defmodule LanpartyseatingWeb.SettingsControllerLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    user_id = 1
    socket = socket
    |> assign(:columns, 12)
    |> assign(:rows, 12)
    |> assign(:col_trailing, true)
    |> assign(:row_trailing, false)
    {:ok, socket}
  end

  def render(assigns) do
    Phoenix.View.render(LanpartyseatingWeb.SettingsView, "settings.html", assigns)
  end

  def handle_event("number", _params, socket) do
    {:noreply, assign(socket, :temperature, 2666)}
  end

  def handle_event("col_trailing", _params, socket) do
    socket = socket
    |> update(:col_trailing, &(!&1))
    {:noreply, socket}
  end

  def handle_event("row_trailing", _params, socket) do
    socket = socket
    |> update(:row_trailing, &(!&1))
    {:noreply, socket}
  end

  def handle_event("change_dimensions", %{"rows" => rows, "columns" => columns}, socket) do
    socket = socket
    |> assign(:rows, String.to_integer(rows))
    |> assign(:columns,String.to_integer(columns))
    {:noreply, socket}
  end

end
