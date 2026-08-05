defmodule Lanpartyseating.SeatMapLayout do
  @moduledoc """
             Decodes, normalizes, and validates seat map layout data.

             Layouts arrive as JSON exported from another event's editor (during onboarding
             and from the map editor's import). That JSON is a string-keyed map of whatever
             the source produced. This module is the single source of truth for turning it
             into the canonical atom-keyed shape the app persists: it decodes, applies
             defaults for missing values, coerces types, and rejects input that is not a
             well-formed layout.

             `SeatMapsLogic` reuses the same normalizers (`normalize_seat/1`,
             `normalize_object/1`, `normalize_label/1`, `atomize_keys/1`) so that every
             path that touches layout data agrees on the canonical shape.

             ## Errors

               * `:invalid_json` - the input is not valid JSON, or is not a JSON object.
               * `:invalid_layout` - the JSON object parsed, but `seats`/`objects` are not
                 lists of maps.
             """

  @type error :: :invalid_json | :invalid_layout
  @type layout :: %{optional(atom()) => any()}

  @doc """
       Decodes a JSON layout string and returns the normalized, validated layout.

       Returns `{:ok, layout}` where `layout` is an atom-keyed map with `:meta`,
       `:seats`, and `:objects` (plus any other top-level fields such as `:width` /
       `:height` / `:background_kind`), or `{:error, reason}`.
       """
  @spec from_json(String.t()) :: {:ok, layout()} | {:error, error()}
  def from_json(json) when is_binary(json) do
    json_library = Phoenix.json_library()

    case json_library.decode(json) do
      {:ok, %{} = decoded} -> normalize_and_validate(decoded)
      {:ok, _non_object} -> {:error, :invalid_json}
      {:error, _exception} -> {:error, :invalid_json}
    end
  end

  def from_json(_other), do: {:error, :invalid_json}

  @doc """
       Normalizes and validates a decoded layout map (string- or atom-keyed).

       Verifies `:seats` and `:objects` are lists of maps (absent entries become
       `[]`), then coerces every value into the canonical shape with defaults.
       """
  @spec normalize_and_validate(map()) :: {:ok, layout()} | {:error, error()}
  def normalize_and_validate(%{} = data) do
    data = atomize_keys(data)

    with {:ok, seats} <- normalize_seats(data[:seats]),
         {:ok, objects} <- normalize_objects(data[:objects]) do
      {:ok,
       data
       |> Map.put(:seats, seats)
       |> Map.put(:objects, objects)
       |> Map.put(:meta, normalize_meta(data[:meta]))}
    end
  end

  def normalize_and_validate(_other), do: {:error, :invalid_layout}

  @doc "Normalizes a single seat to its canonical shape (never raises)."
  @spec normalize_seat(map()) :: map()
  def normalize_seat(%{} = seat) do
    seat = atomize_keys(seat)

    %{
      seat_slot_id: optional_int(seat[:seat_slot_id]),
      label: normalize_label(seat[:label]),
      x: number(seat[:x], 0),
      y: number(seat[:y], 0),
      width: number(seat[:width], 60),
      height: number(seat[:height], 60),
      rotation: number(seat[:rotation], 0),
      shape: string(seat[:shape], "rect"),
      locked: bool(seat[:locked]),
    }
  end

  @doc "Normalizes a single object (shape) to its canonical form (never raises)."
  @spec normalize_object(map()) :: map()
  def normalize_object(%{} = object) do
    object = atomize_keys(object)

    %{
      id: object[:id] || Ecto.UUID.generate(),
      type: string(object[:type], "rect"),
      x: number(object[:x], 0),
      y: number(object[:y], 0),
      width: number(object[:width], 100),
      height: number(object[:height], 100),
      rotation: number(object[:rotation], 0),
      text: object[:text],
      font_size: optional_int(object[:font_size]),
      fill: object[:fill],
      fill_secondary: object[:fill_secondary],
      stroke: object[:stroke],
      locked: bool(object[:locked]),
      front: bool(object[:front]),
    }
  end

  @doc "Normalizes a seat/object label to its canonical uppercase form."
  @spec normalize_label(any()) :: String.t()
  def normalize_label(nil), do: "A01"

  def normalize_label(label) when is_binary(label), do: label |> String.trim() |> String.upcase()

  def normalize_label(label), do: label |> to_string() |> normalize_label()

  @doc "Recursively atomizes map keys, keeping unknown string keys as-is."
  @spec atomize_keys(any()) :: any()
  def atomize_keys(%_{} = struct), do: struct |> Map.from_struct() |> atomize_keys()

  def atomize_keys(%{} = map) do
    Map.new(map, fn {key, value} -> {existing_atom_or_keep(key), atomize_value(value)} end)
  end

  def atomize_keys(other), do: other

  # -- validation internals ---------------------------------------------------

  defp normalize_seats(nil), do: {:ok, []}
  defp normalize_seats(seats) when is_list(seats), do: reduce_entries(seats, &normalize_seat/1)
  defp normalize_seats(_other), do: {:error, :invalid_layout}

  defp normalize_objects(nil), do: {:ok, []}
  defp normalize_objects(objects) when is_list(objects), do: reduce_entries(objects, &normalize_object/1)
  defp normalize_objects(_other), do: {:error, :invalid_layout}

  defp reduce_entries(entries, normalize) do
    entries
    |> Enum.reduce_while(
      {:ok, []},
      fn
        %{} = entry, {:ok, acc} -> {:cont, {:ok, [normalize.(entry) | acc]}}
        _entry, _acc -> {:halt, {:error, :invalid_layout}}
      end
    )
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  end

  defp normalize_meta(%{} = meta), do: meta
  defp normalize_meta(_other), do: %{}

  # -- coercion helpers -------------------------------------------------------

  defp number(value, default) do
    case value do
      value when is_integer(value) -> value
      value when is_float(value) -> round(value)
      value when is_binary(value) -> value |> Float.parse() |> maybe_round(default)
      _other -> default
    end
  end

  defp maybe_round({parsed, _rest}, _default), do: round(parsed)
  defp maybe_round(:error, default), do: default

  defp optional_int(nil), do: nil
  defp optional_int(""), do: nil
  defp optional_int(value), do: number(value, 0)

  defp string(nil, default), do: default
  defp string(value, _default) when is_binary(value), do: value
  defp string(_other, default), do: default

  defp bool(true), do: true
  defp bool("true"), do: true
  defp bool(_other), do: false

  defp existing_atom_or_keep(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end

  defp existing_atom_or_keep(key), do: key

  defp atomize_value(value) when is_map(value), do: atomize_keys(value)
  defp atomize_value(value) when is_list(value), do: Enum.map(value, &atomize_value/1)
  defp atomize_value(value), do: value
end
