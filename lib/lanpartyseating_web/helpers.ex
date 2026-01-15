defmodule LanpartyseatingWeb.Helpers do
  @moduledoc """
  Shared helper functions for LiveView templates.
  """

  @doc """
  Groups a range of indices by padding value for physical table layout.

  When `pad` is 1 or less, returns the range as a single group (no grouping).
  When `pad` > 1, groups indices into chunks of `pad` size.

  ## Examples

      iex> group_by_padding(0..6, 2, 0)
      [[0, 1], [2, 3], [4, 5], [6]]

      iex> group_by_padding(0..9, 1, 0)
      [[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]]
  """
  def group_by_padding(range, pad, _trailing) when pad <= 1 do
    [Enum.to_list(range)]
  end

  def group_by_padding(range, pad, _trailing) do
    range
    |> Enum.to_list()
    |> Enum.chunk_every(pad)
  end
end
