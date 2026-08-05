defmodule Lanpartyseating.SeatMapLayoutTest do
  use ExUnit.Case, async: true

  alias Lanpartyseating.SeatMapLayout

  defp valid_layout_json do
    Jason.encode!(
      %{
        width: 800,
        height: 600,
        meta: %{zoom: 1},
        seats:
          [
            %{seat_slot_id: nil, label: "a01", x: 10, y: 20, width: 60, height: 60, rotation: 0, shape: "rect", locked: false},
          ],
        objects: [],
      }
    )
  end

  describe "from_json/1" do
    test "returns a normalized atom-keyed layout" do
      assert {:ok, layout} = SeatMapLayout.from_json(valid_layout_json())

      assert layout.width == 800
      assert layout.height == 600
      assert layout.meta == %{zoom: 1}

      assert layout.seats ==
               [
                 %{
                   seat_slot_id: nil,
                   label: "A01",
                   x: 10,
                   y: 20,
                   width: 60,
                   height: 60,
                   rotation: 0,
                   shape: "rect",
                   locked: false,
                 },
               ]

      assert layout.objects == []
    end

    test "applies defaults for missing seat fields" do
      json = Jason.encode!(%{seats: [%{x: 1}]})

      assert {:ok, layout} = SeatMapLayout.from_json(json)

      assert [seat] = layout.seats
      assert seat.label == "A01"
      assert seat.y == 0
      assert seat.width == 60
      assert seat.height == 60
      assert seat.shape == "rect"
      assert seat.locked == false
    end

    test "defaults missing seats and objects to empty lists" do
      assert {:ok, layout} = SeatMapLayout.from_json(Jason.encode!(%{meta: %{}}))

      assert layout.seats == []
      assert layout.objects == []
      assert layout.meta == %{}
    end

    test "rejects non-object JSON" do
      assert {:error, :invalid_json} = SeatMapLayout.from_json("42")
      assert {:error, :invalid_json} = SeatMapLayout.from_json("[]")
      assert {:error, :invalid_json} = SeatMapLayout.from_json("\"string\"")
    end

    test "rejects malformed JSON" do
      assert {:error, :invalid_json} = SeatMapLayout.from_json("not json")
    end

    test "rejects non-string input" do
      assert {:error, :invalid_json} = SeatMapLayout.from_json(nil)
    end
  end

  describe "normalize_and_validate/1" do
    test "rejects a layout whose seats are not a list" do
      assert {:error, :invalid_layout} = SeatMapLayout.normalize_and_validate(%{seats: %{}})
    end

    test "rejects a layout whose seats contain a non-map" do
      assert {:error, :invalid_layout} = SeatMapLayout.normalize_and_validate(%{seats: ["nope"]})
    end

    test "rejects a layout whose objects contain a non-map" do
      assert {:error, :invalid_layout} = SeatMapLayout.normalize_and_validate(%{objects: [42]})
    end

    test "rejects a non-map input" do
      assert {:error, :invalid_layout} = SeatMapLayout.normalize_and_validate([])
    end

    test "normalizes string-keyed input" do
      assert {:ok, layout} =
               SeatMapLayout.normalize_and_validate(
                 %{
                   "seats" => [%{"label" => "b02", "x" => "5", "locked" => "true"}],
                 }
               )

      assert [seat] = layout.seats
      assert seat.label == "B02"
      assert seat.x == 5
      assert seat.locked == true
    end
  end
end
