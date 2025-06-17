defmodule LanpartyseatingWeb.TestController do
  use LanpartyseatingWeb, :controller

  def check_badge(conn, %{"badge_number" => badge_num}) do
    IO.inspect(badge_num)
    if badge_num != "69" do
      IO.inspect("not 69")
      conn
      |> send_resp(401, "")
    else
      conn
        |> put_session(:is_admin, true)
        |> send_resp(200, "")
    end
  end

  def reset_admin(conn, _params) do
    conn
        |> put_session(:is_admin, false)
        |> send_resp(200, "")
  end
end
