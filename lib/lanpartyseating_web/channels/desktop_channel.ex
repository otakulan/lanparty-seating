defmodule LanpartyseatingWeb.DesktopChannel do
  use Phoenix.Channel
  alias LanpartyseatingWeb.Presence
  require Logger

  def join("desktop:all", %{"hostname" => hostname} = _message, socket) do
    Logger.debug("Client joined desktop:all with hostname: #{hostname}")
    send(self(), :after_join)
    {:ok, assign(socket, :hostname, hostname)}
  end

  def join("desktop:all", _message, socket) do
    Logger.debug("Client joined desktop:all")
    {:ok, socket}
  end

  def join("desktop:" <> _hostname, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_info(:after_join, socket) do
    Logger.debug("Handling after_join for desktop channel with hostname: #{socket.assigns.hostname}")

    {:ok, _} =
      Presence.track(socket, socket.assigns.hostname, %{
        online_at: inspect(System.system_time(:second)),
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end
end
