defmodule LanpartyseatingWeb.Nav do
  use LanpartyseatingWeb, :live_view

  def on_mount(:default, _params, _session, socket) do
    socket = socket
      |> assign(nav_menu: [
          {"Index", Routes.index_controller_path(socket, :index)},
          {"Badges", Routes.badges_controller_path(socket, :index)},
          {"Participants", Routes.participants_controller_path(socket, :index)},
          {"Settings", Routes.settings_controller_path(socket, :index)},
          {"Management", Routes.management_controller_path(socket, :index)},
          {"Tournaments", Routes.tournaments_controller_path(socket, :index)},
          {"Display", Routes.display_controller_path(socket, :index)},
        ])
      |> attach_hook(:set_nav_menu_active_path, :handle_params, fn
          _params, url, socket ->
            {:cont, assign(socket, nav_menu_active_path: URI.parse(url).path)}
        end)

    {:cont, socket}
  end
end
