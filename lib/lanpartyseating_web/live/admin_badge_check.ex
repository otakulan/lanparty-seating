defmodule LanpartyseatingWeb.AdminBadgeCheck do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.Repo, as: Repo
  require Ecto.Query

  def on_mount(:default, _params, session, socket) do
    is_admin = session["is_admin"] == true
    is_login_page = socket.view == LanpartyseatingWeb.AdminBadgeLoginLive
    socket = socket |> assign(:is_public_page, false)
    if !is_admin and !is_login_page do
      {:halt, redirect(socket, to: ~p"/login")}
    else
      {:cont, socket}
    end
  end

  def render(assigns) do
   ~H"""
    """
  end
end
