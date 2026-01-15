defmodule LanpartyseatingWeb.Nav do
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.Accounts.Scope

  defp public_menu do
    [
      {"Live Display / Affichage en direct", ~p"/"},
      {"Self Sign / Auto-inscription", ~p"/selfsign"},
      {"Cancellation / Annulation", ~p"/cancellation"},
    ]
  end

  defp admin_menu do
    [
      {"Tournaments / Tournois", ~p"/tournaments"},
      {"Settings / Paramètres", ~p"/settings"},
      {"Log / Journal", ~p"/logs"},
    ]
  end

  defp admin_management_menu do
    [
      {"Users / Utilisateurs", ~p"/admin/users"},
      {"Badges", ~p"/admin/badges"},
    ]
  end

  def on_mount(:default, _params, _session, socket) do
    current_scope = socket.assigns[:current_scope]
    is_authenticated = current_scope && current_scope.user
    is_user_auth = Scope.user_auth?(current_scope)

    nav_menu =
      cond do
        is_user_auth ->
          # Full user auth: show all menus including admin management
          public_menu() ++ admin_menu() ++ admin_management_menu()

        is_authenticated ->
          # Badge auth: show admin menu but not admin management
          public_menu() ++ admin_menu()

        true ->
          # Not authenticated: public only
          public_menu()
      end

    socket =
      socket
      |> assign(nav_menu: nav_menu)
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
