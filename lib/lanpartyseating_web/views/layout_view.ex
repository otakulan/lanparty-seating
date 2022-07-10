defmodule LanpartyseatingWeb.LayoutView do
  use LanpartyseatingWeb, :view

  def nav_item(assigns) do
    render "nav_item.html", assigns
  end

  def row(assigns) do
    render "shared/row.html", assigns
  end
end
