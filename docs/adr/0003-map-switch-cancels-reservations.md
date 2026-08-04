# Publishing a different Seat Map cancels every reservation

Publishing a *newer Version of the already-published map* keeps the existing per-seat
guard: you cannot move or remove a Seat that someone is currently sitting in. Publishing
a *different map* skips that guard entirely, cancels all active reservations in one
transaction, and broadcasts a single `seat_map_changed` event on `desktop:all` so every
connected client disconnects its user. An admin confirms the reservation count in a
modal first.

Cross-map publishing is refused outright while a Tournament is underway or within its
buffer. You reconfigure the Room between events, not mid-match.

## Considered Options

Applying the per-seat guard to cross-map publishes was the consistent-looking choice,
but it is unusable: the guard compares seat geometry against the currently published
Version, and essentially every Seat differs between two different maps, so any occupied
Room would block the switch outright. Switching maps mid-event — reconfiguring the room
for a tournament — is precisely the operation the catalogue exists to enable, so the
guard has to yield to it.

For the disconnect signal we considered reusing the existing per-seat
`cancel_reservation` broadcast, which addresses PCs by `station_number`. We rejected it
on two counts: Seats created through the editor have a `nil` `legacy_station_number` and
so are unaddressable, and the one-to-one correspondence between station numbers and PC
assets is being retired. A single room-wide event is also a more honest description of
what happened.

Tournament Holds are neither cancelled nor honoured piecemeal. Cancelling them would
leave the Tournament row running with no Seats allocated, because the lifecycle tasks key
off `tournament_id` rather than the individual reservations — strictly worse than leaving
them. Blocking the switch instead avoids both yanking a competitor mid-game and orphaning
a Tournament.

## Consequences

Desktop clients must learn the new `seat_map_changed` message; until they do, a map
switch cancels reservations server-side without disconnecting anyone. No per-seat
fallback is emitted.

Holds belonging to *future* Tournaments survive a map switch and may end up pointing at
Seats the new map does not place. Detecting that is part of the deferred
publish-safety work.
