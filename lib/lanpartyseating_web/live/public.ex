defmodule LanpartyseatingWeb.Public do
  use LanpartyseatingWeb, :live_view

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:is_public_page, true)
    {:cont, socket}
  end

  def render(assigns) do
    ~H"""
    """
  end
end
