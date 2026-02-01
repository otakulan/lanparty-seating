defmodule Lanpartyseating.BadgeScanner do
  @moduledoc """
  Schema for external badge scanner devices.
  Tokens are hashed with bcrypt and only shown once at creation time.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @token_prefix "lpss_"
  @display_token_chars 8

  schema "badge_scanners" do
    field :name, :string
    field :token_hash, :string
    field :token_prefix, :string
    field :last_seen_at, :utc_datetime
    field :provisioned_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(scanner, attrs) do
    scanner
    |> cast(attrs, [:name, :last_seen_at, :provisioned_at])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 64)
  end

  @doc """
  Creates a changeset for a new scanner with a generated token.
  Returns {changeset, plaintext_token} where plaintext_token should be shown to the user once.
  """
  def create_changeset(attrs) do
    token = generate_token()
    token_hash = Bcrypt.hash_pwd_salt(token)
    display_prefix = @token_prefix <> String.slice(token, 0, @display_token_chars)

    changeset =
      %__MODULE__{}
      |> cast(attrs, [:name])
      |> validate_required([:name])
      |> validate_length(:name, min: 1, max: 64)
      |> put_change(:token_hash, token_hash)
      |> put_change(:token_prefix, display_prefix)

    {changeset, @token_prefix <> token}
  end

  @doc """
  Verifies a plaintext token against a scanner's hash.
  """
  def verify_token(%__MODULE__{token_hash: hash}, @token_prefix <> token) do
    Bcrypt.verify_pass(token, hash)
  end

  def verify_token(nil, _token) do
    Bcrypt.no_user_verify()
    false
  end

  def verify_token(_scanner, _token) do
    # Token doesn't have correct prefix
    Bcrypt.no_user_verify()
    false
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  @doc "Returns the token prefix string used for all scanner tokens"
  def token_prefix, do: @token_prefix

  @doc "Returns the length of the token prefix"
  def token_prefix_length, do: String.length(@token_prefix)

  @doc "Returns the total length of the display prefix (prefix + partial token for identification)"
  def display_prefix_length, do: token_prefix_length() + @display_token_chars

  @doc """
  Regenerates the token for an existing scanner.
  Returns {changeset, plaintext_token} where plaintext_token should be sent to the device.
  """
  def regenerate_token_changeset(scanner) do
    token = generate_token()
    token_hash = Bcrypt.hash_pwd_salt(token)
    display_prefix = @token_prefix <> String.slice(token, 0, @display_token_chars)

    changeset =
      scanner
      |> change(%{token_hash: token_hash, token_prefix: display_prefix})

    {changeset, @token_prefix <> token}
  end
end
