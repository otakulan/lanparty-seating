defmodule LanpartyseatingWeb.Nav do
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.Accounts.Scope

  defp public_menu do
    [
      {"Live Display", ~p"/"},
      {"Self Sign", ~p"/selfsign"},
      {"Cancellation", ~p"/cancellation"},
    ]
  end

  defp admin_menu do
    [
      {"Tournaments", ~p"/tournaments"},
      {"Settings", ~p"/settings"},
      {"Logs", ~p"/logs"},
      {"Maintenance", ~p"/maintenance"},
    ]
  end

  defp admin_management_menu do
    [
      {"Users", ~p"/admin/users"},
      {"Badges", ~p"/admin/badges"},
    ]
  end

  def on_mount(:default, _params, _session, socket) do
    current_scope = socket.assigns[:current_scope]
    is_authenticated = current_scope && current_scope.user
    is_user_auth = Scope.user_auth?(current_scope)

    # Public nav items always visible
    nav_menu = public_menu()

    # Admin dropdown items based on auth level
    admin_dropdown =
      cond do
        is_user_auth ->
          # Full user auth: all admin items including user/badge management
          admin_menu() ++ admin_management_menu()

        is_authenticated ->
          # Badge auth: admin menu but not user/badge management
          admin_menu()

        true ->
          # Not authenticated: no admin dropdown
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
