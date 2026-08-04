# Rooms are alternatives, selected by a global setting

The application serves one Room at a time, chosen by `settings.active_room_id` on the
existing settings singleton. Several Rooms may exist — this year's venue, next year's, a
scratch rebuild — but they are alternatives, not concurrent spaces. `/`, `/map` and
`/kiosk` all resolve the Active Room, so no public route needs a room identifier.

## Considered Options

Making Rooms concurrent — a main hall and a tournament hall live simultaneously, each
with its own kiosks — is the more expressive model and matches what "room" suggests. We
rejected it for now because it touches every public route, the kiosk layout, and how a
physical screen is provisioned, which is a larger change than the seat map catalogue it
was introduced alongside.

Crucially the decision is not a trap: adding `/kiosk/:room_public_id` later is purely
additive, with `settings.active_room_id` demoted to the default for unparameterised
routes. Nothing about the schema forecloses concurrent Rooms.

## Consequences

Switching the Active Room is a room-wide disruption on the same scale as switching the
published Seat Map, and is governed by the same rules: reservations are cancelled,
`seat_map_changed` is broadcast, and the switch is refused while a Tournament is underway
(see ADR-0003). The Active Room cannot be deleted.
