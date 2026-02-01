defmodule LanpartyseatingWeb.Helpers do
  @moduledoc """
  Shared helper functions for LiveView templates.
  """

  @doc """
  Formats a datetime for display in America/Toronto timezone.

  Returns "-" for nil values.

  ## Examples

      iex> format_datetime(~U[2024-01-15 14:30:00Z])
      "2024-01-15 09:30"

      iex> format_datetime(nil)
      "-"
  """
  def format_datetime(nil), do: "-"

  def format_datetime(dt) do
    dt
    |> Timex.to_datetime("America/Toronto")
    |> Calendar.strftime("%Y-%m-%d %H:%M")
  end

  @doc """
  Groups a range of indices by padding value for physical table layout.

  When `pad` is 1 or less, returns the range as a single group (no grouping).
  When `pad` > 1, groups indices into chunks of `pad` size.

  ## Examples

      iex> group_by_padding(0..6, 2)
      [[0, 1], [2, 3], [4, 5], [6]]

      iex> group_by_padding(0..9, 1)
      [[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]]
  """
  def group_by_padding(range, pad) when pad <= 1 do
    [Enum.to_list(range)]
  end

  def group_by_padding(range, pad) do
    range
    |> Enum.to_list()
    |> Enum.chunk_every(pad)
  end

  @doc """
  Formats a datetime as a human-readable relative time string.

  ## Examples

      iex> format_relative_time(DateTime.utc_now())
      "just now"

      iex> format_relative_time(DateTime.add(DateTime.utc_now(), -120, :second))
      "2 min ago"
  """
  def format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} min ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)} hours ago"
      true -> "#{div(diff_seconds, 86400)} days ago"
    end
  end

  @doc """
  Formats Ecto changeset errors into a human-readable string.

  Interpolates error message placeholders (e.g., %{count}) with actual values.

  ## Examples

      iex> changeset = Ecto.Changeset.add_error(%Ecto.Changeset{}, :email, "is invalid")
      iex> format_changeset_errors(changeset)
      "email: is invalid"
  """
  def format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end
end
