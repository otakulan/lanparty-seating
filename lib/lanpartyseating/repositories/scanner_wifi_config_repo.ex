defmodule Lanpartyseating.ScannerWifiConfig do
  @moduledoc """
  Schema for scanner WiFi configuration.
  This is a singleton table - only one row should ever exist.
  WiFi password is encrypted at rest using Plug.Crypto.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @encryption_secret_key_base "scanner_wifi_password_encryption_key"

  schema "scanner_wifi_config" do
    field :ssid, :string
    field :password_encrypted, :binary
    # Virtual field for the decrypted password
    field :password, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:ssid, :password])
    |> validate_required([:ssid])
    |> maybe_require_password()
    |> validate_length(:ssid, min: 1, max: 32)
    |> validate_length(:password, min: 1, max: 63)
    |> encrypt_password()
  end

  defp maybe_require_password(changeset) do
    # Require password for new records (no existing encrypted password)
    if is_nil(get_field(changeset, :password_encrypted)) and is_nil(get_change(changeset, :password)) do
      add_error(changeset, :password, "is required")
    else
      changeset
    end
  end

  defp encrypt_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        secret = get_encryption_key()
        encrypted = Plug.Crypto.encrypt(secret, @encryption_secret_key_base, password)
        put_change(changeset, :password_encrypted, encrypted)
    end
  end

  @doc """
  Decrypts the password from the encrypted binary.
  Returns the config struct with the :password virtual field populated.
  """
  def decrypt_password(%__MODULE__{password_encrypted: nil} = config), do: config

  def decrypt_password(%__MODULE__{password_encrypted: encrypted} = config) do
    secret = get_encryption_key()

    case Plug.Crypto.decrypt(secret, @encryption_secret_key_base, encrypted) do
      {:ok, password} -> %{config | password: password}
      {:error, _} -> config
    end
  end

  defp get_encryption_key do
    Application.get_env(:lanpartyseating, LanpartyseatingWeb.Endpoint)[:secret_key_base]
  end
end
