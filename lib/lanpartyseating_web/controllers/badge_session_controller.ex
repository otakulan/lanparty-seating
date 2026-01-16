defmodule LanpartyseatingWeb.BadgeSessionController do
  use LanpartyseatingWeb, :controller

  alias Lanpartyseating.Accounts
  alias LanpartyseatingWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, error: nil)
  end

  def create(conn, %{"badge" => %{"badge_number" => badge_number}}) do
    case Accounts.get_enabled_admin_badge(badge_number) do
      nil ->
        conn
        |> render(:new, error: "Invalid or disabled badge / Badge invalide ou désactivé")

      badge ->
        conn
        |> UserAuth.log_in_badge(badge)
    end
  end
end
