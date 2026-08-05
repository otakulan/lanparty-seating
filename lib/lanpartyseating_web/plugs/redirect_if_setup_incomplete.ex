defmodule LanpartyseatingWeb.Plugs.RedirectIfSetupIncomplete do
  @moduledoc """
  Gating plug: until onboarding is `:complete`, every browser request is redirected to
  `/setup`. The setup page itself, the liveness/readiness probe paths (`/livez`, `/readyz`),
  the legacy `/healthz` probe, and the `/api` scope are let through untouched.
  """

  import Plug.Conn

  alias Lanpartyseating.OnboardingLogic

  @exempt_prefixes ["/setup", "/livez", "/readyz", "/healthz", "/api"]

  def init(opts), do: opts

  def call(conn, _opts) do
    if exempt?(conn.request_path) or OnboardingLogic.complete?() do
      conn
    else
      conn
      |> Phoenix.Controller.redirect(to: "/setup")
      |> halt()
    end
  end

  defp exempt?(path) do
    Enum.any?(@exempt_prefixes, &String.starts_with?(path, &1))
  end
end
