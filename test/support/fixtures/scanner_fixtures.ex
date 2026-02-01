defmodule Lanpartyseating.ScannerFixtures do
  @moduledoc """
  Test helpers for creating scanner-related entities.
  """
  alias Lanpartyseating.ScannerLogic

  @doc """
  Creates a scanner with a generated token.
  Returns {scanner, plaintext_token}.
  """
  def scanner_fixture(attrs \\ %{}) do
    {:ok, %{scanner: scanner, token: token}} =
      attrs
      |> Enum.into(%{"name" => "Scanner #{System.unique_integer([:positive])}"})
      |> ScannerLogic.create_scanner()

    {scanner, token}
  end

  @doc """
  Creates a WiFi configuration.
  Returns the config struct.
  """
  def wifi_config_fixture(attrs \\ %{}) do
    {:ok, config} =
      attrs
      |> Enum.into(%{"ssid" => "TestNetwork", "password" => "testpassword123"})
      |> ScannerLogic.set_wifi_config()

    config
  end

  @doc """
  Creates a revoked scanner.
  Returns {scanner, original_token}.
  """
  def revoked_scanner_fixture(attrs \\ %{}) do
    {scanner, token} = scanner_fixture(attrs)
    :ok = ScannerLogic.revoke_scanner(scanner.id)
    {:ok, scanner} = ScannerLogic.get_scanner(scanner.id)
    {scanner, token}
  end

  @doc """
  Creates a provisioned scanner.
  Returns {scanner, token}.
  """
  def provisioned_scanner_fixture(attrs \\ %{}) do
    {scanner, token} = scanner_fixture(attrs)
    {:ok, scanner} = ScannerLogic.mark_provisioned(scanner.id)
    {scanner, token}
  end
end
