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
      where: b.uid == ^upper_uid and b.is_admin == true and b.is_banned == false
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
      where: b.id == ^id and b.is_admin == true and b.is_banned == false
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
  # CSV Import
  # ============================================================================

  @doc """
  Imports badges from a CSV file, replacing all existing badges.

  The CSV must have headers and at least two columns: `serial_key` and `uid`.
  All rows are validated through changesets before import. If any row fails
  validation, the entire import is rejected and no changes are made.

  Returns `{:ok, count}` with the number of badges imported,
  or `{:error, reason}` if import fails.
  """
  def import_from_csv(file_path) do
    Repo.transaction(
      fn ->
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        # Parse and validate all rows first
        validated_rows =
          file_path
          |> File.stream!()
          |> BadgesCSV.parse_stream(skip_headers: true)
          |> Stream.with_index(2)
          |> Enum.map(fn {[serial_key, uid | _rest], line_num} ->
            attrs = %{
              serial_key: String.trim(serial_key),
              uid: String.trim(uid),
            }

            changeset = Badge.import_changeset(%Badge{}, attrs)
            {line_num, attrs, changeset}
          end)

        # Check for any invalid rows
        case Enum.find(validated_rows, fn {_, _, cs} -> not cs.valid? end) do
          {line_num, _attrs, changeset} ->
            errors = format_changeset_errors(changeset)
            Repo.rollback("Row #{line_num}: #{errors}")

          nil ->
            # All valid - delete existing and bulk insert
            Repo.delete_all(Badge)

            validated_rows
            |> Enum.map(fn {_, attrs, _} ->
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
        end
      end,
      timeout: :infinity
    )
  end

  @doc """
  Validates a CSV file before import.

  Returns `{:ok, %{row_count: n, sample_rows: [...]}}` if valid,
  or `{:error, reason}` if invalid.
  """
  def validate_csv(file_path) do
    try do
      rows =
        file_path
        |> File.stream!()
        |> BadgesCSV.parse_stream(skip_headers: true)
        |> Enum.take(10_005)

      row_count = length(rows)

      # Check first few rows have required columns
      sample_rows =
        rows
        |> Enum.take(5)
        |> Enum.map(&parse_csv_row/1)

      {:ok, %{row_count: min(row_count, 10_000), sample_rows: sample_rows, truncated: row_count > 10_000}}
    rescue
      e in NimbleCSV.ParseError ->
        {:error, "Invalid CSV format: #{Exception.message(e)}"}

      e in File.Error ->
        {:error, "File error: #{Exception.message(e)}"}

      _e in [MatchError, FunctionClauseError] ->
        {:error, "CSV must have at least two columns: serial_key, uid"}
    end
  end

  defp parse_csv_row([serial_key, uid | _rest]) do
    %{serial_key: String.trim(serial_key), uid: String.trim(uid)}
  end

  @doc """
  Formats changeset errors into a human-readable string.
  """
  def format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end
end
