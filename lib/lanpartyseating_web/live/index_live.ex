defmodule LanpartyseatingWeb.IndexLive do
  use LanpartyseatingWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="col-span-2 hero">
      <img src="/images/lanparty.png" />
      <h1 style="font-size:40px">
        <br /><br /><br /><br /><br /><br /><%= gettext("Welcome to %{name}!", name: "LAN Party Seating") %>
      </h1>
    </div>
    """
  end
end
