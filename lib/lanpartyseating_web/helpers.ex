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
end
