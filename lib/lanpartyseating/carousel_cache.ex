defmodule Lanpartyseating.CarouselCache do
  @moduledoc """
  ETS-backed GenServer that caches carousel images in memory at startup.

  Images are loaded from the database once on boot and refreshed on demand
  after CRUD operations. The ETS table is `:public` read so LiveViews can
  read directly without bottlenecking the GenServer process.

  ## Cache structure

  The ETS table stores two kinds of entries:
  - `{:image, id}` => full image map (for serving image data)
  - `:enabled_list` => ordered list of enabled image metadata (no blob data)
  - `:all_list` => ordered list of all image metadata (for admin, no blob data)
  """
  use GenServer

  alias Lanpartyseating.{Repo, CarouselImage}
  import Ecto.Query

  @table :carousel_images_cache

  # --- Client API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Returns enabled carousel images ordered by display_order (metadata only, no blobs)."
  def list_images do
    case :ets.lookup(@table, :enabled_list) do
      [{:enabled_list, images}] -> images
      [] -> []
    end
  end

  @doc "Returns all carousel images ordered by display_order (metadata only, for admin)."
  def list_all_images do
    case :ets.lookup(@table, :all_list) do
      [{:all_list, images}] -> images
      [] -> []
    end
  end

  @doc "Returns {content_type, binary_data} for a given image ID, or nil if not found."
  def get_image_data(id) do
    case :ets.lookup(@table, {:image, id}) do
      [{{:image, _}, %{content_type: ct, image_data: data}}] -> {ct, data}
      [] -> nil
    end
  end

  @doc "Triggers a synchronous reload from the database. Blocks until ETS is updated."
  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  # --- Server callbacks ---

  @impl true
  def init(_) do
    table = :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    load_from_db()
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    load_from_db()
    {:reply, :ok, state}
  end

  defp load_from_db do
    images =
      from(i in CarouselImage, order_by: [asc: i.display_order, asc: i.id])
      |> Repo.all()

    # Store full image data keyed by ID (for serving)
    # First, clear old image entries
    :ets.match_delete(@table, {{:image, :_}, :_})

    for img <- images do
      :ets.insert(@table, {{:image, img.id}, %{content_type: img.content_type, image_data: img.image_data}})
    end

    # Store metadata lists (without blob data, for LiveView assigns)
    metadata_fn = fn img ->
      %{
        id: img.id,
        title: img.title,
        content_type: img.content_type,
        display_order: img.display_order,
        enabled: img.enabled,
        inserted_at: img.inserted_at,
      }
    end

    all_list = Enum.map(images, metadata_fn)
    enabled_list = all_list |> Enum.filter(& &1.enabled)

    :ets.insert(@table, {:all_list, all_list})
    :ets.insert(@table, {:enabled_list, enabled_list})
  end
end
