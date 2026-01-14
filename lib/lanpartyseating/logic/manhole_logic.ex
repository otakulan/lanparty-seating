defmodule Lanpartyseating.ManholeLogic do
  @moduledoc """
  Logic module for manhole broadcasting functionality.
  Handles tournament start broadcasts to desktop clients.
  """

  require Logger
  alias LanpartyseatingWeb.Endpoint

  @doc """
  Broadcasts tournament start command to a single station.

  ## Parameters
  - station_number: The station number as a string or integer

  ## Returns
  - {:ok, station_num} on success
  - {:error, message} on validation failure or broadcast error
  """
  @spec broadcast_single_station(String.t() | integer()) ::
          {:ok, integer()} | {:error, String.t()}
  def broadcast_single_station(station_number) do
    case validate_single_station(station_number) do
      {:ok, station_num} ->
        try do
          Endpoint.broadcast(
            "desktop:all",
            "tournament_start",
            %{
              station_number: station_num,
            }
          )

          Logger.info("Broadcasted tournament start for station #{station_num}")
          {:ok, station_num}
        rescue
          error ->
            Logger.error("Failed to broadcast to station #{station_num}: #{inspect(error)}")
            {:error, "Failed to broadcast tournament start command"}
        end

      {:error, message} ->
        {:error, message}
    end
  end

  @doc """
  Broadcasts cancel reservation command to a single station.

  ## Parameters
  - station_number: The station number as a string or integer

  ## Returns
  - {:ok, station_num} on success
  - {:error, message} on validation failure or broadcast error
  """
  @spec cancel_single_station(String.t() | integer()) :: {:ok, integer()} | {:error, String.t()}
  def cancel_single_station(station_number) do
    case validate_single_station(station_number) do
      {:ok, station_num} ->
        try do
          Endpoint.broadcast(
            "desktop:all",
            "cancel_reservation",
            %{
              station_number: station_num,
            }
          )

          Logger.info("Broadcasted cancel reservation for station #{station_num}")
          {:ok, station_num}
        rescue
          error ->
            Logger.error("Failed to broadcast cancel reservation to station #{station_num}: #{inspect(error)}")

            {:error, "Failed to broadcast cancel reservation command"}
        end

      {:error, message} ->
        {:error, message}
    end
  end

  @doc """
  Broadcasts cancel reservation command to a range of stations.

  ## Parameters
  - range_start: The start station number as a string or integer
  - range_end: The end station number as a string or integer

  ## Returns
  - {:ok, start_num, end_num} on success
  - {:error, message} on validation failure or broadcast error
  """
  @spec cancel_station_range(String.t() | integer(), String.t() | integer()) :: {:ok, integer(), integer()} | {:error, String.t()}
  def cancel_station_range(range_start, range_end) do
    case validate_range(range_start, range_end) do
      {:ok, start_num, end_num} ->
        try do
          Enum.each(start_num..end_num, fn station_num ->
            Endpoint.broadcast(
              "desktop:all",
              "cancel_reservation",
              %{
                station_number: station_num,
              }
            )
          end)

          Logger.info("Broadcasted cancel reservation for stations #{start_num} to #{end_num}")
          {:ok, start_num, end_num}
        rescue
          error ->
            Logger.error("Failed to broadcast cancel reservation to station range #{start_num}-#{end_num}: #{inspect(error)}")

            {:error, "Failed to broadcast cancel reservation commands"}
        end

      {:error, message} ->
        {:error, message}
    end
  end

  @doc """
  Broadcasts tournament start command to a range of stations.

  ## Parameters
  - range_start: The start station number as a string or integer
  - range_end: The end station number as a string or integer

  ## Returns
  - {:ok, start_num, end_num} on success
  - {:error, message} on validation failure or broadcast error
  """
  @spec broadcast_station_range(String.t() | integer(), String.t() | integer()) :: {:ok, integer(), integer()} | {:error, String.t()}
  def broadcast_station_range(range_start, range_end) do
    case validate_range(range_start, range_end) do
      {:ok, start_num, end_num} ->
        try do
          Enum.each(start_num..end_num, fn station_num ->
            Endpoint.broadcast(
              "desktop:all",
              "tournament_start",
              %{
                station_number: station_num,
              }
            )
          end)

          Logger.info("Broadcasted tournament start for stations #{start_num} to #{end_num}")
          {:ok, start_num, end_num}
        rescue
          error ->
            Logger.error("Failed to broadcast to station range #{start_num}-#{end_num}: #{inspect(error)}")

            {:error, "Failed to broadcast tournament start commands"}
        end

      {:error, message} ->
        {:error, message}
    end
  end

  # Private validation functions

  @spec validate_single_station(String.t() | integer()) :: {:ok, integer()} | {:error, String.t()}
  defp validate_single_station(station_number) when is_integer(station_number) do
    if station_number > 0 do
      {:ok, station_number}
    else
      {:error, "Station number must be a positive integer"}
    end
  end

  defp validate_single_station(station_number) when is_binary(station_number) do
    case Integer.parse(station_number) do
      {num, ""} when num > 0 ->
        {:ok, num}

      {_num, _} ->
        {:error, "Station number must be a valid positive integer"}

      :error ->
        {:error, "Station number must be a valid positive integer"}
    end
  end

  defp validate_single_station(_), do: {:error, "Station number is required"}

  @spec validate_range(String.t() | integer(), String.t() | integer()) :: {:ok, integer(), integer()} | {:error, String.t()}
  defp validate_range(range_start, range_end)
       when is_binary(range_start) and is_binary(range_end) do
    with {:ok, start_num} <- validate_single_station(range_start),
         {:ok, end_num} <- validate_single_station(range_end) do
      if start_num <= end_num do
        {:ok, start_num, end_num}
      else
        {:error, "Start station must be less than or equal to end station"}
      end
    else
      {:error, _} -> {:error, "Both start and end stations must be valid positive integers"}
    end
  end

  defp validate_range(range_start, range_end)
       when is_integer(range_start) and is_integer(range_end) do
    with {:ok, start_num} <- validate_single_station(range_start),
         {:ok, end_num} <- validate_single_station(range_end) do
      if start_num <= end_num do
        {:ok, start_num, end_num}
      else
        {:error, "Start station must be less than or equal to end station"}
      end
    else
      {:error, message} -> {:error, message}
    end
  end

  defp validate_range(_, _), do: {:error, "Both start and end stations are required"}
end
