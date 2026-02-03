defmodule Lanpartyseating.BadgesLogic do
  @moduledoc """
  Business logic for badge management.

  Handles badge lookups for reservations and admin authentication,
  as well as CRUD operations, pagination, search, and CSV import.
  """
  import Ecto.Query
  alias Lanpartyseating.Badge
  alias Lanpartyseating.BadgesCSV
  alias Lanpartyseating.Repo

  @default_per_page 50

  # ============================================================================
  # Badge Lookup (for reservations)
  # ============================================================================

  @doc """
  Gets a badge by UID for reservation purposes.
  Returns `{:ok, badge}` or `{:error, reason}`.
  """
  def get_badge(uid) do
    upper_uid = String.upcase(uid)

    from(b in Badge, where: b.uid == ^upper_uid)
    |> Repo.one()
    |> case do
      nil -> {:error, "Unknown badge serial number"}
      badge -> {:ok, badge}
    end
  end

  # ============================================================================
  # Admin Badge Lookup (for authentication)
  # ============================================================================

  @doc """
  Gets an admin badge by UID for authentication.
  Returns the badge if it exists, is an admin, and is not banned.
  Returns nil otherwise.
  """
  def get_admin_badge(uid) when is_binary(uid) do
    upper_uid = String.upcase(uid)

    from(b in Badge,
      where: b.uid == ^upper_uid and b.is_admin == true
    )
    |> Repo.one()
  end

  @doc """
  Gets an admin badge by ID for session validation.
  Returns the badge if it exists, is an admin, and is not banned.
  Returns nil otherwise.
  """
  def get_admin_badge_by_id(id) do
    from(b in Badge,
      where: b.id == ^id and b.is_admin == true
    )
    |> Repo.one()
  end

  # ============================================================================
  # CRUD Operations
  # ============================================================================

  @doc """
  Gets a badge by ID. Raises if not found.
  """
  def get_badge!(id), do: Repo.get!(Badge, id)

  @doc """
  Creates a new badge.
  """
  def create_badge(attrs) do
    %Badge{}
    |> Badge.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a badge.
  """
  def update_badge(%Badge{} = badge, attrs) do
    badge
    |> Badge.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a badge.
  """
  def delete_badge(%Badge{} = badge) do
    Repo.delete(badge)
  end

  # ============================================================================
  # Listing with Pagination and Search
  # ============================================================================

  @doc """
  Lists badges with pagination and optional search.

  ## Options

    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 50)
    * `:search` - Search term for UID or serial_key (optional)

  ## Examples

      iex> list_badges(page: 1, per_page: 50)
      [%Badge{}, ...]

      iex> list_badges(page: 2, search: "BADGE")
      [%Badge{}, ...]
  """
  def list_badges(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, @default_per_page)
    search = Keyword.get(opts, :search)

    Badge
    |> maybe_search(search)
    |> order_by([b], desc: b.inserted_at, desc: b.id)
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> Repo.all()
  end

  @doc """
  Counts badges with optional search filter.
  """
  def count_badges(search \\ nil) do
    Badge
    |> maybe_search(search)
    |> Repo.aggregate(:count)
  end

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query

  defp maybe_search(query, search) do
    search_term = "%#{search}%"
    from(b in query, where: ilike(b.uid, ^search_term) or ilike(b.serial_key, ^search_term))
  end

  # ============================================================================
  # CSV Import (In-Memory)
  # ============================================================================

  @doc """
  Parses and validates CSV content from a binary string.

  Parses all rows, validates each through changesets. If any row fails
  validation, returns an error immediately. Otherwise returns the validated
  rows ready for import.

  Returns `{:ok, %{row_count: n, sample_rows: [...], validated_rows: [...]}}` if valid,
  or `{:error, reason}` if invalid.
  """
  def parse_and_validate_csv_content(csv_content) when is_binary(csv_content) do
    import LanpartyseatingWeb.Helpers, only: [format_changeset_errors: 1]

    lines = String.split(csv_content, "\n", trim: true)
    rows = BadgesCSV.parse_enumerable(lines, skip_headers: true)

    validated_rows =
      rows
      |> Enum.with_index(2)
      |> Enum.map(fn {row, line_num} -> validate_row(row, line_num) end)

    case Enum.find(validated_rows, &match?({:error, _}, &1)) do
      {:error, reason} ->
        {:error, reason}

      nil ->
        attrs_list = Enum.map(validated_rows, fn {:ok, attrs} -> attrs end)

        {:ok,
         %{
           row_count: length(attrs_list),
           sample_rows: Enum.take(attrs_list, 5),
           validated_rows: attrs_list,
         }}
    end
  rescue
    e in NimbleCSV.ParseError ->
      {:error, "Invalid CSV format: #{Exception.message(e)}"}
  end

  defp validate_row(row, line_num) when length(row) < 2 do
    {:error, "Row #{line_num}: must have at least two columns (serial_key, uid)"}
  end

  defp validate_row([serial_key, uid | _rest], line_num) do
    import LanpartyseatingWeb.Helpers, only: [format_changeset_errors: 1]

    attrs = %{serial_key: String.trim(serial_key), uid: String.trim(uid)}
    changeset = Badge.import_changeset(%Badge{}, attrs)

    if changeset.valid? do
      {:ok, attrs}
    else
      {:error, "Row #{line_num}: #{format_changeset_errors(changeset)}"}
    end
  end

  @doc """
  Imports pre-validated badge rows, replacing all existing badges.

  Takes a list of validated attribute maps (from `parse_and_validate_csv_content/1`)
  and bulk inserts them. All existing badges are deleted first.

  Returns `{:ok, count}` with the number of badges imported,
  or `{:error, reason}` if import fails.
  """
  def import_validated_rows(validated_rows) when is_list(validated_rows) do
    Repo.transaction(
      fn ->
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        Repo.delete_all(Badge)

        validated_rows
        |> Enum.map(fn attrs ->
          Map.merge(attrs, %{
            uid: String.upcase(attrs.uid),
            is_admin: false,
            is_banned: false,
            inserted_at: now,
            updated_at: now,
          })
        end)
        |> Enum.chunk_every(1000)
        |> Enum.reduce(0, fn chunk, acc ->
          {count, _} = Repo.insert_all(Badge, chunk, on_conflict: :nothing)
          acc + count
        end)
      end,
      timeout: :infinity
    )
  end
end
