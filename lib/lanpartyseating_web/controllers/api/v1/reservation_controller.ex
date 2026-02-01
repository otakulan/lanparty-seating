defmodule LanpartyseatingWeb.Api.V1.ReservationController do
  @moduledoc """
  API controller for reservation operations from external badge scanners.
  """
  use LanpartyseatingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Lanpartyseating.ReservationLogic
  alias LanpartyseatingWeb.Api.V1.Schemas

  tags(["Reservations"])
  security([%{"bearer" => []}])

  operation(:cancel,
    summary: "Cancel reservation by badge",
    description: """
    Cancels the active reservation for the badge holder.
    Called by external badge scanners when a user scans their badge to sign out.
    """,
    request_body: {"Cancel request", "application/json", Schemas.CancelRequest},
    responses: [
      ok: {"Reservation cancelled", "application/json", Schemas.SuccessResponse},
      bad_request: {"Invalid request", "application/json", Schemas.ErrorResponse},
      unauthorized: {"Invalid or missing token", "application/json", Schemas.ErrorResponse},
      not_found: {"Badge or reservation not found", "application/json", Schemas.ErrorResponse},
    ]
  )

  def cancel(conn, %{"badge_uid" => badge_uid}) when is_binary(badge_uid) and badge_uid != "" do
    case ReservationLogic.cancel_reservation_by_badge(badge_uid) do
      {:ok, %{message: message}} ->
        json(conn, %{status: "ok", message: message})

      {:error, :badge_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Unknown badge"})

      {:error, :no_reservation} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "No active reservation found for this badge"})

      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: "An unexpected error occurred"})
    end
  end

  def cancel(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{status: "error", message: "badge_uid is required"})
  end
end
