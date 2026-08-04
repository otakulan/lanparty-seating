# LAN Party Seating

Manages gaming station reservations at a LAN party event: who sits where, on which
machine, for how long. Identity comes from badge scans, not accounts.

## Language

### Physical space

**Room**:
A physical space that holds Seats — a venue layout for an event. Several may exist (this
year's hall, next year's, a scratch copy), but they are alternatives rather than
concurrent spaces: only the Active Room is ever shown.
_Avoid_: venue, hall, site

**Active Room**:
The one Room the whole application currently serves, chosen by a global setting.
Displays, kiosks and the public map all resolve it.
_Avoid_: current room, default room, selected room

**Seat**:
A physical place an attendee can sit, owned by the Room and identified by a label like
`A01`. Its identity, PC assignment, broken flag and reservation history persist across
every Seat Map.
_Avoid_: station, slot, seat slot, desk

**PC Asset**:
A machine in the inventory, tracked independently of where it currently sits. At most
one PC Asset is assigned to a Seat at a time, and vice versa.
_Avoid_: station, computer, machine, box

**Seat Assignment**:
The current pairing of a PC Asset with a Seat. Moving a machine means retiring one
assignment and creating another.
_Avoid_: mapping, allocation

### Layout

**Seat Map**:
A named, saved arrangement of the Room's Seats — where each one sits on the canvas,
plus decorative Objects. A Seat Map places Seats; it does not own them.
_Avoid_: layout, floor plan, map version

**Version**:
An immutable snapshot of a Seat Map's contents. Every save appends a new one; none is
ever modified after creation. Versions are numbered per Seat Map by `revision`.
_Avoid_: draft, revision (as a noun for the snapshot itself)

**Published Version**:
The single Version the Room is currently pointing at — what attendees and displays see.
Publishing a Seat Map points the Room at that map's newest Version.
_Avoid_: active map, live map, current layout

**Object**:
Non-seat decoration drawn on a Seat Map: tables, walls, text signage. Carries no
domain meaning and is never reservable.
_Avoid_: shape, element, annotation

### Occupancy

**Reservation**:
An attendee actively using the PC Asset at a Seat — a logged-in, in-use machine. Started
by a badge scan, ended by expiry, cancellation, or a Room-wide Seat Map switch.
Cancelling one puts a real person out of their seat.
_Avoid_: booking, session, claim

**Tournament Hold**:
A Seat set aside for a scheduled Tournament, applied ahead of the start time by the
tournament buffer. Before the Tournament starts it blocks an empty Seat; once underway
it covers a Seat in active use.
_Avoid_: tournament reservation, lock
