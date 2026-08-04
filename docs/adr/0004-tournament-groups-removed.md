# Seat groups and tournament team assignments removed from the Seat Map

The editor previously let you lasso Seats into a named group and bind a tournament team
to that group, stored in `tournament_team_assignments` and rendered as coloured overlays.
We dropped the table, the editor panel and the rendering. Tournaments will get their own
UI built around PC Assets and a schedule, so the Seat Map has no reason to know about
them — and keeping the binding alive would have forced team assignments to be copied
into a new row on every single save once Versions became append-only.

Do not restore group-based team assignment when building the new tournament UI. Resolve
tournament participation through PC Assets, and from there to Seats, so the Seat Map
stays a pure description of where things are.

## Consequences

Displays lose the team-name overlay until the new tournament UI ships. Decorative
Objects (tables, text labels) are unaffected and remain in the editor. `data.groups` is
silently discarded when older Version blobs are read.
