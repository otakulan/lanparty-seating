defmodule Lanpartyseating.SettingsLogic do
  import Ecto.Query

  def get_settings do
    Lanpartyseating.Setting
    |> last(:inserted_at)
    |> Lanpartyseating.Repo.one()
  end

  def save_settings(rows, columns, row_padding, column_padding, horizontal_trailing, vertical_trailing) do
    settings = Lanpartyseating.Setting
    |> last(:inserted_at)
    |> Lanpartyseating.Repo.one()

    settings = Ecto.Changeset.change settings, rows: rows, columns: columns, row_padding: row_padding,
      column_padding: column_padding, horizontal_trailing: horizontal_trailing, vertical_trailing: vertical_trailing
    case Lanpartyseating.Repo.update settings do
      {:ok, struct}       -> settings
      {:error, changeset} -> nil
    end
  end

end
