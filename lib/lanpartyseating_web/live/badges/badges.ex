defmodule LanpartyseatingWeb.BadgesControllerLive do
  use Phoenix.LiveView

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      Phoenix.View.render(LanpartyseatingWeb.BadgesView, "badges.html", assigns)
    end

  end
