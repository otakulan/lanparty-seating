defmodule LanpartyseatingWeb.CarouselImageController do
  @moduledoc """
  Serves carousel image binaries from the in-memory cache.
  Public endpoint — no authentication required.
  """
  use LanpartyseatingWeb, :controller

  alias Lanpartyseating.CarouselLogic

  def show(conn, %{"id" => id}) do
    case Integer.parse(id) do
      {int_id, ""} ->
        case CarouselLogic.get_image_data(int_id) do
          {content_type, data} ->
            conn
            |> put_resp_content_type(content_type)
            |> put_resp_header("cache-control", "public, max-age=300")
            |> send_resp(200, data)

          nil ->
            send_resp(conn, 404, "Not found")
        end

      _ ->
        send_resp(conn, 400, "Invalid ID")
    end
  end
end
