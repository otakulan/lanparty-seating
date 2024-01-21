defmodule Lanpartyseating.BadgesLogic do
  import Ecto.Query
  alias Lanpartyseating.Badge, as: Badge
  alias Lanpartyseating.Repo, as: Repo

  def get_badge(uid) do
    min_uid = String.upcase(uid)

    badge = from(s in Badge,
        where: s.uid == ^min_uid
      )
      |> Repo.one()

    case badge do
      nil -> {:error, "Unknown badge serial number"}
      _ -> {:ok, badge}
    end
  end
end
