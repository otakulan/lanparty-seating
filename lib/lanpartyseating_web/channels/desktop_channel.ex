defmodule LanpartyseatingWeb.DesktopChannel do
  use Phoenix.Channel
  require Logger

  def join("desktop:all", _message, socket) do
    Logger.debug("Client joined desktop:all")
    {:ok, socket}
  end

  def join("desktop:" <> _hostname, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end
end
