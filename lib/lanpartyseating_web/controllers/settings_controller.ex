defmodule LanpartyseatingWeb.SettingsController do
  use LanpartyseatingWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
