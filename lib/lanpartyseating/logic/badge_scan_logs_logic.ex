defmodule Lanpartyseating.BadgeScanLogsLogic do
  import Ecto.Query
  alias Lanpartyseating.BadgeScanLogs, as: BadgeScanLogs
  alias Lanpartyseating.Repo, as: Repo

  def get_all_participants do
    BadgeScanLogs
    |> Repo.all()
  end

end
