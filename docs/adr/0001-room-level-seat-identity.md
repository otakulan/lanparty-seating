# Seat identity belongs to the Room, not to a Seat Map

Introducing a catalogue of multiple Seat Maps forced a choice about what a Seat is: a
fixture of the Room that maps merely place, or a thing each map owns. We made Seats
belong to the Room (`seat_slots.room_id`), so a Seat Map's stored data only references
`seat_slot_id` plus geometry. This means PC assignments, broken flags and reservation
history follow a Seat automatically across every map, and swapping the published map
never has to re-point the assignment table.

## Considered Options

Map-owned Seats were the obvious reading of the original schema
(`seat_slots.seat_map_id`), but they break down immediately: `seat_slot_assignments`
enforces one PC per Seat globally via a partial unique index, so `A01` on the Friday
map and `A01` on the Saturday map would be different rows competing for the same
machine. Every map switch would have to match Seats by label and migrate assignments —
duplicated identity, label-collision edge cases, and no stable target for
`reservations.seat_slot_id`.

## Consequences

A Seat can exist while no map places it. Such Seats are currently invisible: the editor
only renders placed Seats and there is no Seats & PCs management page yet. Until one
exists, a Seat stranded off the published map keeps its PC and history but cannot be
seen or reserved.
