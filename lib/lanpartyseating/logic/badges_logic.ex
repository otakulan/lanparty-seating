defmodule Lanpartyseating.BadgesLogic do
  import Ecto.Query
  alias Lanpartyseating.Badge
  alias Lanpartyseating.Repo

  def get_badge(uid) do
    upper_uid = String.upcase(uid)

    badge =
      from(b in Badge,
        where: b.uid == ^upper_uid
      )
      |> Repo.one()

    case badge do
      nil -> {:error, "Unknown badge serial number"}
      _ -> {:ok, badge}
    end
  end
end
