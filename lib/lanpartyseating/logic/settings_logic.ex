defmodule Lanpartyseating.SettingsLogic do
  import Ecto.Query

  def get_settings do
    Lanpartyseating.Setting
    |> last(:inserted_at)
    |> Lanpartyseating.Repo.one()
  end
end
