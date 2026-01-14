defmodule LanpartyseatingWeb.Nav do
  use LanpartyseatingWeb, :live_view

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(
        nav_menu: [
          {"Live Display", ~p"/"},
          # {"Auto assign", ~p"/autoassign"},
          {"Self Sign", ~p"/selfsign"},
          {"Cancellation", ~p"/cancellation"}

          # ADMIN PAGE - DO NOT DISPLAY
          # {"Tournaments", ~p"/tournaments"},
          # {"Settings", ~p"/settings"},
          # {"Log", ~p"/logs"}
        ]
      )
      |> attach_hook(:set_nav_menu_active_path, :handle_params, fn
        _params, url, socket ->
          {:cont, assign(socket, nav_menu_active_path: URI.parse(url).path)}
      end)

    {:cont, socket}
  end

  def render(assigns) do
    ~H"""
    """
  end
end
