defmodule LanpartyseatingWeb.SettingsControllerLive do
  use LanpartyseatingWeb, :live_view
  use Phoenix.LiveView

  #def mount(_params, _session, socket) do
  #  socket = assign(socket, :brightness, 10)
  #  IO.inspect(socket)
  #  {:ok, socket}
  #end

  def mount(_params, _session, socket) do
    user_id = 1
    #temperature = Thermostat.get_user_reading(user_id)
    socket = assign(socket, :temperature, 241)
    socket = assign(socket, :columns, 12)
    socket = assign(socket, :rows, 12)
    {:ok, socket}
  end

  def render(assigns) do
    Phoenix.View.render(LanpartyseatingWeb.SettingsView, "settings.html", assigns)
  end

  #def index(conn, _params) do
  #  #socket.assigns.retard = "sigma male"
  #  IO.puts "SHIT"
  #  render conn, "index.html"
  #end

  def handle_event("number", _, socket) do
    {:noreply, assign(socket, :temperature, 2666)}
  end

  def handle_event("change_dimensions", params, socket) do
    IO.inspect(params)
    #IO.inspect(cols)
    socket = assign(socket, :rows, String.to_integer(params["rows"]))
    socket = assign(socket, :columns, String.to_integer(params["columns"]))
    {:noreply, socket}
  end


end
