defmodule Lanpartyseating.CarouselLogic do
  @moduledoc """
  Business logic for managing carousel images displayed on the public display page.
  """
  import Ecto.Query
  alias Lanpartyseating.{Repo, CarouselImage, CarouselCache}

  @pubsub Lanpartyseating.PubSub
  @topic "carousel_update"

  # ============================================================================
  # Read operations (delegate to cache)
  # ============================================================================

  @doc "Returns enabled carousel images ordered by display_order (metadata only)."
  def list_images, do: CarouselCache.list_images()

  @doc "Returns all carousel images ordered by display_order (metadata only, for admin)."
  def list_all_images, do: CarouselCache.list_all_images()

  @doc "Returns {content_type, binary_data} for a given image ID, or nil."
  def get_image_data(id), do: CarouselCache.get_image_data(id)

  # ============================================================================
  # Write operations
  # ============================================================================

  @doc """
  Creates a new carousel image from upload data.
  Automatically assigns the next display_order.
  Returns {:ok, image} or {:error, changeset}.
  """
  def create_image(attrs) do
    # Auto-assign display_order to end of list if not specified
    attrs = maybe_assign_order(attrs)

    case %CarouselImage{} |> CarouselImage.changeset(attrs) |> Repo.insert() do
      {:ok, image} ->
        refresh_and_broadcast()
        {:ok, image}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates carousel image metadata (title, display_order, enabled).
  Does not replace image data — use create + delete for that.
  Returns {:ok, image} or {:error, changeset}.
  """
  def update_image(id, attrs) do
    with {:ok, image} <- get_image(id) do
      case image |> CarouselImage.metadata_changeset(attrs) |> Repo.update() do
        {:ok, image} ->
          refresh_and_broadcast()
          {:ok, image}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Permanently deletes a carousel image.
  Returns :ok or {:error, reason}.
  """
  def delete_image(id) do
    with {:ok, image} <- get_image(id),
         {:ok, _} <- Repo.delete(image) do
      refresh_and_broadcast()
      :ok
    end
  end

  @doc """
  Reorders images by assigning new display_order values.
  Takes a list of image IDs in the desired order.
  Returns :ok.
  """
  def reorder_images(ordered_ids) when is_list(ordered_ids) do
    ordered_ids =
      Enum.map(ordered_ids, fn
        id when is_integer(id) -> id
        id when is_binary(id) -> String.to_integer(id)
      end)

    # Single bulk UPDATE using unnest join — avoids N+1 queries
    orders = Enum.to_list(0..(length(ordered_ids) - 1))

    from(i in CarouselImage,
      join: v in fragment("SELECT * FROM unnest(?::int[], ?::int[]) AS v(id, ord)", ^ordered_ids, ^orders),
      on: i.id == v.id,
      update: [set: [display_order: v.ord, updated_at: ^DateTime.utc_now()]]
    )
    |> Repo.update_all([])

    refresh_and_broadcast()
    :ok
  end

  # ============================================================================
  # Private helpers
  # ============================================================================

  defp get_image(id) do
    case Repo.get(CarouselImage, id) do
      nil -> {:error, :not_found}
      image -> {:ok, image}
    end
  end

  defp maybe_assign_order(attrs) when is_map(attrs) do
    if Map.has_key?(attrs, :display_order) || Map.has_key?(attrs, "display_order") do
      attrs
    else
      max_order =
        from(i in CarouselImage, select: max(i.display_order))
        |> Repo.one()
        |> Kernel.||(0)

      Map.put(attrs, :display_order, max_order + 1)
    end
  end

  defp refresh_and_broadcast do
    CarouselCache.refresh()
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:carousel, :updated})
  end
end
