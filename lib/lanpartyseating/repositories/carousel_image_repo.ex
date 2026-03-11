defmodule Lanpartyseating.CarouselImage do
  @moduledoc """
  Schema for game cover images displayed in the carousel on the display page.
  Images are stored as binary blobs in the database and cached in ETS at runtime.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @allowed_content_types ~w(image/jpeg image/png image/webp)
  @max_file_size 2 * 1024 * 1024

  schema "carousel_images" do
    field :title, :string
    field :image_data, :binary
    field :content_type, :string
    field :display_order, :integer, default: 0
    field :enabled, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating a new carousel image from an upload."
  def changeset(image, attrs) do
    image
    |> cast(attrs, [:title, :image_data, :content_type, :display_order, :enabled])
    |> validate_required([:image_data, :content_type])
    |> validate_inclusion(:content_type, @allowed_content_types, message: "must be JPEG, PNG, or WebP")
    |> validate_number(:display_order, greater_than_or_equal_to: 0)
    |> validate_length(:title, max: 255)
    |> validate_file_size()
  end

  @doc "Changeset for updating metadata (title, order, enabled) without replacing image data."
  def metadata_changeset(image, attrs) do
    image
    |> cast(attrs, [:title, :display_order, :enabled])
    |> validate_number(:display_order, greater_than_or_equal_to: 0)
    |> validate_length(:title, max: 255)
  end

  defp validate_file_size(changeset) do
    validate_change(changeset, :image_data, fn :image_data, data ->
      if byte_size(data) > @max_file_size do
        [image_data: "must be less than 2MB"]
      else
        []
      end
    end)
  end

  def allowed_content_types, do: @allowed_content_types
  def max_file_size, do: @max_file_size
end
