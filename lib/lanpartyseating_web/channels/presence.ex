defmodule LanpartyseatingWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence,
    otp_app: :lanpartyseating,
    pubsub_server: Lanpartyseating.PubSub
end
