defmodule Lanpartyseating.BadgesLogic do
  import Ecto.Query
  alias Lanpartyseating.Badge, as: Badge
  alias Lanpartyseating.Repo, as: Repo

  def get_badge(serial_key) do
    from(s in Badge,
      where: s.serial_key == ^serial_key
    )
    |> Repo.one()
  end
end
