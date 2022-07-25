defmodule LanpartyseatingWeb.IndexControllerLive do
use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    Phoenix.View.render(LanpartyseatingWeb.IndexView, "index.html", assigns)
  end

end
