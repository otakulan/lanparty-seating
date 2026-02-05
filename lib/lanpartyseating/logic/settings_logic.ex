defmodule Lanpartyseating.SettingsLogic do
  import Ecto.Query
  alias Lanpartyseating.Setting
  alias Lanpartyseating.Repo

  def get_settings do
    Repo.get!(Setting, 1)
  end

  @doc """
  Creates an Ecto.Multi that updates the settings table.
  The object returned from this function needs to be written to the database by the caller.
  If no settings exist, creates a new record with schema defaults.

  Accepts a map of attributes to update. Only the provided keys will be changed.

  ## Examples

      # Update only grid padding
      settings_db_changes(%{row_padding: 2, column_padding: 3})

      # Update only reservation settings
      settings_db_changes(%{reservation_duration_minutes: 60, tournament_buffer_minutes: 30})
  """
  def settings_db_changes(attrs) when is_map(attrs) do
    settings =
      Repo.get(Setting, 1)
      |> case do
        # should be impossible
        nil -> %Setting{}
        existing -> existing
      end

    changeset = Setting.changeset(settings, attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.insert_or_update(:insert_settings, changeset)
  end
end
