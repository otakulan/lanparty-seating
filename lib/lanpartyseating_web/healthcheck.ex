defmodule LanpartyseatingWeb.HealthCheck do
  use HeartCheck
  import Ecto.Adapters.SQL
  alias Lanpartyseating.Repo, as: Repo

  add :database do
    try do
      query(Repo, "SELECT 1")
    rescue
      e in RuntimeError -> e
    end
    |> case do
      {:ok, _} -> :ok
      _ -> :error
    end
  end
end
