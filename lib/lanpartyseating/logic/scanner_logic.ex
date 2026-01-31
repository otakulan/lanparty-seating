defmodule Lanpartyseating.ScannerLogic do
  @moduledoc """
  Business logic for managing external badge scanners and their WiFi configuration.
  """
  import Ecto.Query
  alias Lanpartyseating.Repo
  alias Lanpartyseating.BadgeScanner
  alias Lanpartyseating.ScannerWifiConfig

  # ============================================================================
  # Scanner CRUD
  # ============================================================================

  @doc """
  Creates a new scanner with a generated API token.
  Returns {:ok, %{scanner: scanner, token: plaintext_token}} on success.
  The plaintext token is only available at creation time.
  """
  def create_scanner(attrs) do
    {changeset, token} = BadgeScanner.create_changeset(attrs)

    case Repo.insert(changeset) do
      {:ok, scanner} -> {:ok, %{scanner: scanner, token: token}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Lists all scanners (including revoked ones for audit purposes).
  """
  def list_scanners do
    from(s in BadgeScanner, order_by: [desc: s.inserted_at])
    |> Repo.all()
  end

  @doc """
  Lists only active (non-revoked) scanners.
  """
  def list_active_scanners do
    from(s in BadgeScanner, where: is_nil(s.revoked_at), order_by: [desc: s.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets a scanner by ID.
  """
  def get_scanner(id) do
    case Repo.get(BadgeScanner, id) do
      nil -> {:error, :not_found}
      scanner -> {:ok, scanner}
    end
  end

  @doc """
  Revokes a scanner's token (soft-revoke for audit trail).
  """
  def revoke_scanner(id) do
    with {:ok, scanner} <- get_scanner(id),
         {:ok, _} <- do_revoke(scanner) do
      :ok
    end
  end

  defp do_revoke(%BadgeScanner{revoked_at: nil} = scanner) do
    scanner
    |> BadgeScanner.changeset(%{revoked_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.update()
  end

  defp do_revoke(%BadgeScanner{}), do: {:error, :already_revoked}

  @doc """
  Permanently deletes a scanner.
  """
  def delete_scanner(id) do
    with {:ok, scanner} <- get_scanner(id),
         {:ok, _} <- Repo.delete(scanner) do
      :ok
    end
  end

  @doc """
  Marks a scanner as provisioned.
  """
  def mark_provisioned(id) do
    with {:ok, scanner} <- get_scanner(id) do
      scanner
      |> BadgeScanner.changeset(%{provisioned_at: DateTime.utc_now() |> DateTime.truncate(:second)})
      |> Repo.update()
    end
  end

  @doc """
  Updates the last_seen_at timestamp for a scanner.
  Called after successful API authentication.
  """
  def update_last_seen(scanner_id) do
    from(s in BadgeScanner, where: s.id == ^scanner_id)
    |> Repo.update_all(set: [last_seen_at: DateTime.utc_now() |> DateTime.truncate(:second)])

    :ok
  end

  # ============================================================================
  # Token Verification
  # ============================================================================

  @doc """
  Verifies an API token and returns the scanner if valid.
  Returns {:ok, scanner} if valid, {:error, :invalid} if token is wrong,
  {:error, :revoked} if scanner is revoked.
  """
  def verify_token(token) do
    # Extract prefix to narrow down candidates (optimization)
    # Token prefix is "lpss_" (5 chars) + 8 chars from token = 13 chars
    prefix = String.slice(token, 0, 13)

    scanners =
      from(s in BadgeScanner, where: s.token_prefix == ^prefix)
      |> Repo.all()

    case Enum.find(scanners, &BadgeScanner.verify_token(&1, token)) do
      nil ->
        {:error, :invalid}

      %BadgeScanner{revoked_at: revoked_at} when not is_nil(revoked_at) ->
        {:error, :revoked}

      scanner ->
        {:ok, scanner}
    end
  end

  # ============================================================================
  # WiFi Configuration (Singleton)
  # ============================================================================

  @doc """
  Gets the WiFi configuration with decrypted password.
  Returns {:ok, config} or {:error, :not_configured}.
  """
  def get_wifi_config do
    case Repo.one(from(c in ScannerWifiConfig, limit: 1)) do
      nil -> {:error, :not_configured}
      config -> {:ok, ScannerWifiConfig.decrypt_password(config)}
    end
  end

  @doc """
  Sets or updates the WiFi configuration.
  Returns {:error, :scanners_exist} if scanners are already configured.
  """
  def set_wifi_config(attrs) do
    if can_edit_wifi_config?() do
      do_set_wifi_config(attrs)
    else
      {:error, :scanners_exist}
    end
  end

  defp do_set_wifi_config(attrs) do
    case Repo.one(from(c in ScannerWifiConfig, limit: 1)) do
      nil ->
        %ScannerWifiConfig{}
        |> ScannerWifiConfig.changeset(attrs)
        |> Repo.insert()

      config ->
        config
        |> ScannerWifiConfig.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Returns true if WiFi config can be edited (no scanners exist).
  """
  def can_edit_wifi_config? do
    count = Repo.one(from(s in BadgeScanner, select: count("*")))
    count == 0
  end

  @doc """
  Returns the count of scanners.
  """
  def scanner_count do
    Repo.one(from(s in BadgeScanner, select: count("*")))
  end
end
