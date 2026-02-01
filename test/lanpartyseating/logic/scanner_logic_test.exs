defmodule Lanpartyseating.ScannerLogicTest do
  use Lanpartyseating.DataCase, async: true

  alias Lanpartyseating.ScannerLogic

  import Lanpartyseating.ScannerFixtures

  # ============================================================================
  # Scanner CRUD
  # ============================================================================

  describe "create_scanner/1" do
    test "creates scanner with valid name" do
      assert {:ok, %{scanner: scanner, token: token}} =
               ScannerLogic.create_scanner(%{"name" => "Exit A"})

      assert scanner.name == "Exit A"
      assert scanner.token_hash != nil
      assert scanner.token_prefix =~ ~r/^lpss_/
      assert token =~ ~r/^lpss_/
    end

    test "returns plaintext token only at creation time" do
      {:ok, %{scanner: _scanner, token: token}} =
        ScannerLogic.create_scanner(%{"name" => "Test"})

      # Token should be full length (lpss_ + 43 chars base64)
      assert String.length(token) > 40
      assert String.starts_with?(token, "lpss_")
    end

    test "fails with empty name" do
      assert {:error, changeset} = ScannerLogic.create_scanner(%{"name" => ""})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "fails with name longer than 64 characters" do
      long_name = String.duplicate("a", 65)
      assert {:error, changeset} = ScannerLogic.create_scanner(%{"name" => long_name})
      assert "should be at most 64 character(s)" in errors_on(changeset).name
    end
  end

  describe "list_scanners/0" do
    test "returns empty list when no scanners" do
      assert ScannerLogic.list_scanners() == []
    end

    test "returns all scanners" do
      {scanner1, _} = scanner_fixture(%{"name" => "Scanner 1"})
      {scanner2, _} = scanner_fixture(%{"name" => "Scanner 2"})

      scanners = ScannerLogic.list_scanners()
      assert length(scanners) == 2
      assert Enum.any?(scanners, &(&1.id == scanner1.id))
      assert Enum.any?(scanners, &(&1.id == scanner2.id))
    end

    test "orders by inserted_at descending" do
      {scanner1, _} = scanner_fixture(%{"name" => "First"})
      {scanner2, _} = scanner_fixture(%{"name" => "Second"})

      [first, second] = ScannerLogic.list_scanners()
      assert first.id == scanner2.id
      assert second.id == scanner1.id
    end
  end

  describe "get_scanner/1" do
    test "returns {:ok, scanner} when found" do
      {scanner, _} = scanner_fixture()
      assert {:ok, found} = ScannerLogic.get_scanner(scanner.id)
      assert found.id == scanner.id
    end

    test "returns {:error, :not_found} when not found" do
      assert {:error, :not_found} = ScannerLogic.get_scanner(999_999)
    end
  end

  describe "delete_scanner/1" do
    test "permanently deletes scanner" do
      {scanner, _} = scanner_fixture()
      assert :ok = ScannerLogic.delete_scanner(scanner.id)
      assert {:error, :not_found} = ScannerLogic.get_scanner(scanner.id)
    end

    test "returns {:error, :not_found} if not found" do
      assert {:error, :not_found} = ScannerLogic.delete_scanner(999_999)
    end
  end

  describe "mark_provisioned/1" do
    test "sets provisioned_at timestamp" do
      {scanner, _} = scanner_fixture()
      assert is_nil(scanner.provisioned_at)

      assert {:ok, provisioned} = ScannerLogic.mark_provisioned(scanner.id)
      assert provisioned.provisioned_at != nil
    end

    test "returns {:error, :not_found} if not found" do
      assert {:error, :not_found} = ScannerLogic.mark_provisioned(999_999)
    end
  end

  describe "update_last_seen/1" do
    test "updates last_seen_at timestamp" do
      {scanner, _} = scanner_fixture()
      assert is_nil(scanner.last_seen_at)

      assert :ok = ScannerLogic.update_last_seen(scanner.id)

      {:ok, updated} = ScannerLogic.get_scanner(scanner.id)
      assert updated.last_seen_at != nil
    end

    test "broadcasts to scanner_update topic" do
      {scanner, _} = scanner_fixture()
      scanner_id = scanner.id
      Phoenix.PubSub.subscribe(Lanpartyseating.PubSub, "scanner_update")

      ScannerLogic.update_last_seen(scanner.id)

      assert_receive {:scanner_seen, ^scanner_id}
    end
  end

  describe "regenerate_token/1" do
    test "generates new token" do
      {scanner, original_token} = scanner_fixture()

      assert {:ok, new_token} = ScannerLogic.regenerate_token(scanner.id)
      assert new_token != original_token
      assert String.starts_with?(new_token, "lpss_")
    end

    test "updates token_hash and token_prefix" do
      {scanner, _} = scanner_fixture()
      original_prefix = scanner.token_prefix

      {:ok, _new_token} = ScannerLogic.regenerate_token(scanner.id)
      {:ok, updated} = ScannerLogic.get_scanner(scanner.id)

      assert updated.token_prefix != original_prefix
      assert updated.token_hash != scanner.token_hash
    end

    test "returns {:error, :not_found} if not found" do
      assert {:error, :not_found} = ScannerLogic.regenerate_token(999_999)
    end
  end

  # ============================================================================
  # Token Verification
  # ============================================================================

  describe "verify_token/1" do
    test "returns {:ok, scanner} for valid token" do
      {scanner, token} = scanner_fixture()
      assert {:ok, verified} = ScannerLogic.verify_token(token)
      assert verified.id == scanner.id
    end

    test "returns {:error, :invalid} for wrong token" do
      scanner_fixture()
      assert {:error, :invalid} = ScannerLogic.verify_token("lpss_wrongtoken12345678901234567890123")
    end

    test "returns {:error, :invalid} for malformed token" do
      scanner_fixture()
      assert {:error, :invalid} = ScannerLogic.verify_token("not_a_valid_token")
    end

    test "returns {:error, :invalid} for token without prefix" do
      scanner_fixture()
      assert {:error, :invalid} = ScannerLogic.verify_token("missing_prefix_token")
    end

    test "returns {:error, :invalid} when no scanners exist" do
      assert {:error, :invalid} = ScannerLogic.verify_token("lpss_anytoken123456789012345678901234")
    end
  end

  # ============================================================================
  # WiFi Configuration
  # ============================================================================

  describe "get_wifi_config/0" do
    test "returns {:error, :not_configured} when no config exists" do
      assert {:error, :not_configured} = ScannerLogic.get_wifi_config()
    end

    test "returns {:ok, config} with decrypted password" do
      wifi_config_fixture(%{"ssid" => "MyNetwork", "password" => "secret123"})

      assert {:ok, config} = ScannerLogic.get_wifi_config()
      assert config.ssid == "MyNetwork"
      assert config.password == "secret123"
    end
  end

  describe "set_wifi_config/1" do
    test "creates new config with valid params" do
      assert {:ok, config} =
               ScannerLogic.set_wifi_config(%{"ssid" => "NewNetwork", "password" => "newpass123"})

      assert config.ssid == "NewNetwork"
      assert config.password_encrypted != nil
    end

    test "updates existing config" do
      wifi_config_fixture(%{"ssid" => "OldNetwork", "password" => "oldpass"})

      assert {:ok, config} =
               ScannerLogic.set_wifi_config(%{"ssid" => "UpdatedNetwork", "password" => "newpass"})

      assert config.ssid == "UpdatedNetwork"

      # Verify only one config exists
      {:ok, fetched} = ScannerLogic.get_wifi_config()
      assert fetched.ssid == "UpdatedNetwork"
    end

    test "allows SSID-only update keeping existing password" do
      wifi_config_fixture(%{"ssid" => "OldNetwork", "password" => "keepthis"})

      # Update only SSID, omit password
      assert {:ok, _config} = ScannerLogic.set_wifi_config(%{"ssid" => "NewSSID", "password" => ""})

      {:ok, fetched} = ScannerLogic.get_wifi_config()
      assert fetched.ssid == "NewSSID"
      assert fetched.password == "keepthis"
    end

    test "returns {:error, :scanners_exist} when scanners exist" do
      wifi_config_fixture()
      scanner_fixture()

      assert {:error, :scanners_exist} =
               ScannerLogic.set_wifi_config(%{"ssid" => "Blocked", "password" => "blocked"})
    end

    test "fails with missing SSID" do
      assert {:error, changeset} = ScannerLogic.set_wifi_config(%{"password" => "onlypass"})
      assert "can't be blank" in errors_on(changeset).ssid
    end

    test "fails with missing password on new config" do
      assert {:error, changeset} = ScannerLogic.set_wifi_config(%{"ssid" => "NoPassword"})
      assert "is required" in errors_on(changeset).password
    end

    test "fails with SSID longer than 32 characters" do
      long_ssid = String.duplicate("a", 33)

      assert {:error, changeset} =
               ScannerLogic.set_wifi_config(%{"ssid" => long_ssid, "password" => "valid"})

      assert "should be at most 32 character(s)" in errors_on(changeset).ssid
    end

    test "fails with password longer than 63 characters" do
      long_password = String.duplicate("a", 64)

      assert {:error, changeset} =
               ScannerLogic.set_wifi_config(%{"ssid" => "Valid", "password" => long_password})

      assert "should be at most 63 character(s)" in errors_on(changeset).password
    end
  end

  describe "can_edit_wifi_config?/0" do
    test "returns true when no scanners exist" do
      assert ScannerLogic.can_edit_wifi_config?() == true
    end

    test "returns false when scanners exist" do
      wifi_config_fixture()
      scanner_fixture()
      assert ScannerLogic.can_edit_wifi_config?() == false
    end
  end

  describe "scanner_count/0" do
    test "returns 0 when no scanners" do
      assert ScannerLogic.scanner_count() == 0
    end

    test "returns correct count" do
      scanner_fixture()
      scanner_fixture()
      assert ScannerLogic.scanner_count() == 2
    end
  end
end
