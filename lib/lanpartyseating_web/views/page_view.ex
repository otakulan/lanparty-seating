defmodule LanpartyseatingWeb.PageView do
  use LanpartyseatingWeb, :view

  def row(assigns) do
    render "shared/row.html", assigns
  end
end
