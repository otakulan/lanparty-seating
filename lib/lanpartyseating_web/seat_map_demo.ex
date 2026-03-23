defmodule LanpartyseatingWeb.SeatMapDemo do
  @moduledoc false

  @seat_width 56
  @seat_height 56
  @seat_gap 78

  def interactive_payload do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{
      id: "seat-map-demo",
      name: "Salle LAN Otakuthon / Otakuthon LAN Room",
      status: "published",
      width: 2520,
      height: 1480,
      background_kind: "none",
      background_value: nil,
      meta: %{"zoom" => 1, "minScale" => 0.38, "maxScale" => 4},
      seats: seats(now),
      objects: room_objects(),
      groups: seat_groups(),
      team_assignments: team_assignments(),
    }
  end

  def editor_payload do
    payload = interactive_payload()

    %{
      payload
      | seats: Enum.map(payload.seats, &Map.merge(&1, %{"status" => "available", "reservation_end_date" => nil})),
        team_assignments: [],
    }
  end

  def seat_details(seat_slot_id) do
    interactive_payload()
    |> Map.fetch!(:seats)
    |> Enum.find(fn seat -> seat["seat_slot_id"] == seat_slot_id end)
  end

  defp seats(now) do
    row_layouts()
    |> Enum.with_index(1)
    |> Enum.flat_map(
      fn {row, row_index} ->
        Enum.map(
          1..10,
          fn column ->
            seat_id = (row_index - 1) * 10 + column
            label = "#{row.letter}#{String.pad_leading(Integer.to_string(column), 2, "0")}"
            x = row.x_start + (column - 1) * @seat_gap
            y = row.y
            {status, minutes} = status_for(seat_id)

            seat(seat_id, label, x, y, status, now, minutes)
          end
        )
      end
    )
  end

  defp seat(id, label, x, y, status, now, minutes) do
    %{
      "seat_slot_id" => id,
      "label" => label,
      "x" => x,
      "y" => y,
      "width" => @seat_width,
      "height" => @seat_height,
      "rotation" => 0,
      "shape" => "retro-computer",
      "status" => Atom.to_string(status),
      "reservation_end_date" => reservation_end_date(status, now, minutes),
      "legacy_station_number" => id,
      "pc_asset_code" => String.downcase(label),
      "pc_hostname" => "#{String.downcase(label)}.lan",
    }
  end

  defp status_for(seat_id) do
    cond do
      seat_id in (Enum.to_list(6..10) ++ Enum.to_list(16..20)) -> {:tournament, nil}
      seat_id in (Enum.to_list(61..65) ++ Enum.to_list(71..75)) -> {:tournament, nil}
      seat_id in [34, 55, 87] -> {:unavailable, nil}
      seat_id in [3, 4, 28, 36, 53, 54, 82, 83] -> {:occupied, 21}
      seat_id in [46, 47, 92, 93] -> {:reserved, 14}
      true -> {:available, nil}
    end
  end

  defp reservation_end_date(status, now, minutes) when status in [:occupied, :reserved] do
    now
    |> DateTime.add(minutes * 60, :second)
    |> DateTime.to_iso8601()
  end

  defp reservation_end_date(_status, _now, _minutes), do: nil

  defp room_objects do
    [
      rect("room-shell", 70, 84, 2380, 1260, "#f9f6f0", "#ccbea7", "#fdfbf8"),
      rect("left-zone", 122, 136, 1090, 1032, "#f5ede2", "#c6b49a", "#fbf7f1"),
      rect("right-zone", 1310, 136, 1088, 1032, "#eef4f3", "#8ca89d", "#f8fbfa"),
      rect("stage-bar", 126, 1202, 1100, 98, "#273943", "#142028", "#39505d"),
      rect("stream-booth", 1590, 1206, 250, 96, "#efe2d5", "#ba8861", "#faf0e6"),
      rect("lounge", 1868, 1206, 270, 96, "#edf1f5", "#909aa7", "#fafcfd"),
      rect("support", 2164, 1206, 200, 96, "#dbe5f3", "#6f8eb2", "#eef5fd"),
      text("left-title", 164, 174, 480, 40, "Tournoi principal / Main tournament", "#35434d", 30),
      text("right-title", 1354, 174, 340, 40, "Jeu libre / Free play", "#2d4b46", 30),
      text("stage-title", 162, 1234, 320, 28, "Scene / Stage", "#eef2f5", 22),
      text("stream-title", 1630, 1238, 180, 28, "Stream Booth", "#7b563b", 18),
      text("lounge-title", 1954, 1238, 120, 28, "Lounge", "#566274", 18),
      text("support-title", 2214, 1238, 120, 28, "Support", "#37577c", 18),
    ] ++ table_blocks()
  end

  defp table_blocks do
    [
      table_block("ab", 162, 214, "#dec7a8", "#937257", "#eedfc8"),
      table_block("cd", 162, 520, "#dec7a8", "#937257", "#eedfc8"),
      table_block("ef", 162, 826, "#dec7a8", "#937257", "#eedfc8"),
      table_block("gh", 1350, 214, "#d7e1ef", "#617a9f", "#edf2fb"),
      table_block("ij", 1350, 520, "#d7e1ef", "#617a9f", "#edf2fb"),
    ]
  end

  defp table_block(id, x, y, fill, stroke, fill_secondary) do
    rect("table-#{id}", x, y, 930, 166, fill, stroke, fill_secondary)
  end

  defp seat_groups do
    [
      %{
        "id" => "valorant-alpha",
        "name" => "Team Kitsune",
        "seat_slot_ids" => Enum.to_list(6..10) ++ Enum.to_list(16..20),
        "color" => "#0f766e",
      },
      %{
        "id" => "rocket-league-alpha",
        "name" => "Team Photon",
        "seat_slot_ids" => Enum.to_list(61..65) ++ Enum.to_list(71..75),
        "color" => "#2563eb",
      },
      %{
        "id" => "duo-showmatch",
        "name" => "Duo Showmatch",
        "seat_slot_ids" => [46, 47],
        "color" => "#7c3aed",
      },
    ]
  end

  defp team_assignments do
    [
      %{
        "group_id" => "valorant-alpha",
        "team_name" => "Team Kitsune",
        "color" => "#0f766e",
        "tournament_name" => "Valorant",
      },
      %{
        "group_id" => "rocket-league-alpha",
        "team_name" => "Team Photon",
        "color" => "#2563eb",
        "tournament_name" => "Rocket League",
      },
    ]
  end

  defp row_layouts do
    [
      row("A", 206, 254),
      row("B", 206, 344),
      row("C", 206, 560),
      row("D", 206, 650),
      row("E", 206, 866),
      row("F", 206, 956),
      row("G", 1394, 254),
      row("H", 1394, 344),
      row("I", 1394, 560),
      row("J", 1394, 650),
    ]
  end

  defp row(letter, x_start, y) do
    %{
      letter: letter,
      x_start: x_start,
      y: y,
    }
  end

  defp rect(id, x, y, width, height, fill, stroke, fill_secondary) do
    %{
      "id" => id,
      "type" => "rect",
      "x" => x,
      "y" => y,
      "width" => width,
      "height" => height,
      "rotation" => 0,
      "fill" => fill,
      "fill_secondary" => fill_secondary,
      "stroke" => stroke,
    }
  end

  defp text(id, x, y, width, height, text, fill, font_size) do
    %{
      "id" => id,
      "type" => "text",
      "x" => x,
      "y" => y,
      "width" => width,
      "height" => height,
      "rotation" => 0,
      "text" => text,
      "fill" => fill,
      "font_size" => font_size,
      "stroke" => "transparent",
    }
  end
end
