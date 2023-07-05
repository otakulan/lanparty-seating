defmodule LanpartyseatingWeb.Nav do
  use LanpartyseatingWeb, :live_view

  def on_mount(:default, _params, _session, socket) do
    socket = socket
      |> assign(nav_menu: [
          {"Index", ~p"/"},
          {"Badges", ~p"/badges"},
          {"Participants", ~p"/participants"},
          {"Settings", ~p"/settings"},
          {"Management", ~p"/management"},
          {"Tournaments", ~p"/tournaments"},
          {"Display", ~p"/display"},
        ])
      |> attach_hook(:set_nav_menu_active_path, :handle_params, fn
          _params, url, socket ->
            {:cont, assign(socket, nav_menu_active_path: URI.parse(url).path)}
        end)

    {:cont, socket}
  end
end
