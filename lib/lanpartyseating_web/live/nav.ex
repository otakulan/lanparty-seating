defmodule LanpartyseatingWeb.Nav do
  use LanpartyseatingWeb, :live_view

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(
        nav_menu: [
          {"Index", ~p"/"},
          {"Live Display", ~p"/display"},
          {"Auto assign", ~p"/badges"},
          {"Self Sign", ~p"/selfsign"},
          {"Management", ~p"/management"},
          {"Tournaments", ~p"/tournaments"},
          {"Log", ~p"/participants"},
          {"Settings", ~p"/settings"}
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
