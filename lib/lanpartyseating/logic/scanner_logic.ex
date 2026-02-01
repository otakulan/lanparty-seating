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
  Ordered by inserted_at descending, with id as tiebreaker for deterministic ordering.
  """
  def list_scanners do
    from(s in BadgeScanner, order_by: [desc: s.inserted_at, desc: s.id])
    |> Repo.all()
  end

  @doc """
  Lists only active (non-revoked) scanners.
  Ordered by inserted_at descending, with id as tiebreaker for deterministic ordering.
  """
  def list_active_scanners do
    from(s in BadgeScanner, where: is_nil(s.revoked_at), order_by: [desc: s.inserted_at, desc: s.id])
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
  Broadcasts to "scanner_update" topic for real-time UI updates.
  """
  def update_last_seen(scanner_id) do
    from(s in BadgeScanner, where: s.id == ^scanner_id)
    |> Repo.update_all(set: [last_seen_at: DateTime.utc_now() |> DateTime.truncate(:second)])

    Phoenix.PubSub.broadcast(Lanpartyseating.PubSub, "scanner_update", {:scanner_seen, scanner_id})
    :ok
  end

  @doc """
  Regenerates the API token for a scanner.
  Returns {:ok, plaintext_token} or {:error, reason}.
  The new token should be sent to the device during provisioning.
  """
  def regenerate_token(scanner_id) do
    with {:ok, scanner} <- get_scanner(scanner_id) do
      {changeset, token} = BadgeScanner.regenerate_token_changeset(scanner)

      case Repo.update(changeset) do
        {:ok, _} -> {:ok, token}
        {:error, changeset} -> {:error, changeset}
      end
    end
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

    # Check each candidate scanner, handling revoked status explicitly
    # BadgeScanner.verify_token returns false for revoked scanners (timing attack protection)
    # so we need to check the hash manually for revoked scanners
    find_matching_scanner(scanners, token)
  end

  defp find_matching_scanner([], _token), do: {:error, :invalid}

  defp find_matching_scanner([scanner | rest], token) do
    case check_scanner_token(scanner, token) do
      {:ok, scanner} -> {:ok, scanner}
      {:error, :revoked} -> {:error, :revoked}
      {:error, :invalid} -> find_matching_scanner(rest, token)
    end
  end

  defp check_scanner_token(%BadgeScanner{revoked_at: revoked_at} = scanner, token)
       when not is_nil(revoked_at) do
    # Scanner is revoked - check if the token would have matched
    if verify_token_hash(scanner, token) do
      {:error, :revoked}
    else
      {:error, :invalid}
    end
  end

  defp check_scanner_token(scanner, token) do
    if BadgeScanner.verify_token(scanner, token) do
      {:ok, scanner}
    else
      {:error, :invalid}
    end
  end

  # Verify token hash without checking revoked status (for revoked scanner check)
  defp verify_token_hash(%BadgeScanner{token_hash: hash}, "lpss_" <> token) do
    Bcrypt.verify_pass(token, hash)
  end

  defp verify_token_hash(_, _), do: false

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
        # New config - password required
        %ScannerWifiConfig{}
        |> ScannerWifiConfig.changeset(attrs)
        |> Repo.insert()

      config ->
        # Update - password optional (keep existing if empty)
        attrs =
          if attrs["password"] in [nil, ""] do
            Map.delete(attrs, "password")
          else
            attrs
          end

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
