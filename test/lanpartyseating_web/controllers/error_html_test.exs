defmodule LanpartyseatingWeb.ErrorHTMLTest do
  use LanpartyseatingWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    result = render_to_string(LanpartyseatingWeb.ErrorHTML, "404", "html", [])
    assert result =~ "404"
    assert result =~ "Page not found"
  end

  test "renders 500.html" do
    result = render_to_string(LanpartyseatingWeb.ErrorHTML, "500", "html", [])
    assert result =~ "500"
    assert result =~ "Internal server error"
  end
end
