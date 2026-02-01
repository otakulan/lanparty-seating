defmodule LanpartyseatingWeb.Nav do
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.Accounts.Scope

  defp public_menu do
    [
      {"Live Display", ~p"/"},
      {"Stations", ~p"/stations"},
    ]
  end

  defp admin_menu do
    [
      {"Tournaments", ~p"/tournaments"},
      {"Settings", ~p"/settings/seating"},
      {"Logs", ~p"/logs"},
      {"Maintenance", ~p"/maintenance"},
    ]
  end

  def on_mount(:default, _params, _session, socket) do
    current_scope = socket.assigns[:current_scope]
    is_authenticated = current_scope && current_scope.user
    is_user_auth = Scope.user_auth?(current_scope)

    # Public nav items always visible
    nav_menu = public_menu()

    # Admin dropdown items based on auth level
    # Users/Badges management is now in the Settings sidebar, not the main nav
    admin_dropdown =
      if is_authenticated do
        admin_menu()
      else
        []
      end

    socket =
      socket
      |> assign(nav_menu: nav_menu)
      |> assign(admin_menu: admin_dropdown)
      |> assign(is_authenticated: is_authenticated)
      |> assign(is_user_auth: is_user_auth)
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
