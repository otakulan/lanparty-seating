defmodule LanpartyseatingWeb.Plugs.ScannerAuth do
  @moduledoc """
  Plug for authenticating badge scanner API requests via Bearer token.

  On successful authentication, assigns :scanner to the connection.
  Updates the scanner's last_seen_at timestamp.
  """
  import Plug.Conn
  alias Lanpartyseating.ScannerLogic

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- extract_token(conn),
         {:ok, scanner} <- ScannerLogic.verify_token(token) do
      # Update last seen asynchronously to not slow down the request
      Task.start(fn -> ScannerLogic.update_last_seen(scanner.id) end)

      assign(conn, :scanner, scanner)
    else
      {:error, :missing_token} ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{status: "error", message: "Missing or invalid Authorization header"})
        |> halt()

      {:error, :invalid} ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{status: "error", message: "Invalid token"})
        |> halt()

      {:error, :revoked} ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.json(%{status: "error", message: "Token has been revoked"})
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing_token}
    end
  end
end
