defmodule Lanpartyseating.SettingsLogic do
  import Ecto.Query
  alias Lanpartyseating.Setting, as: Setting
  alias Lanpartyseating.Repo, as: Repo

  def get_settings do
    Setting
    |> last(:inserted_at)
    |> Repo.one()
  end

  def save_settings(rows, columns, row_padding, column_padding, horizontal_trailing, vertical_trailing) do
    settings = Setting
    |> last(:inserted_at)
    |> Repo.one()

    settings = Ecto.Changeset.change settings, rows: rows, columns: columns, row_padding: row_padding,
      column_padding: column_padding, horizontal_trailing: horizontal_trailing, vertical_trailing: vertical_trailing
    case Repo.update settings do
      {:ok, result}       -> result
      {:error, _} -> nil
    end
  end

end
