defmodule Lanpartyseating.SettingsLogic do
  import Ecto.Query
  require Logger
  alias Lanpartyseating.Setting
  alias Lanpartyseating.Repo

  def get_settings do
    settings =
      Setting
      |> last(:inserted_at)
      |> Repo.one()

    case settings do
      nil -> {:error, "No settings found"}
      _ -> {:ok, settings}
    end
  end

  @doc """
  Creates an Ecto.Multi that updates the settings table.
  The object returned from this function needs to be written to the database by the caller.
  If no settings exist, creates a new record with schema defaults.
  """
  def settings_db_changes(row_padding, column_padding) do
    settings =
      Setting
      |> last(:inserted_at)
      |> Repo.one()
      |> case do
        nil -> %Setting{}
        existing -> existing
      end

    changeset =
      Setting.changeset(settings, %{
        row_padding: row_padding,
        column_padding: column_padding,
      })

    Ecto.Multi.new()
    |> Ecto.Multi.insert_or_update(:insert_settings, changeset)
  end
end
