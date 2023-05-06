defmodule LanpartyseatingWeb.ParticipantsControllerLive do
  use Phoenix.LiveView

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      Phoenix.View.render(LanpartyseatingWeb.ParticipantsView, "participants.html", assigns)
    end

  end
