defmodule LanpartyseatingWeb.AdminBadgeLoginLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.Repo, as: Repo
  require Ecto.Query

  def on_mount(:default, _params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <p>meow</p>
    </div>
    """
  end
end
