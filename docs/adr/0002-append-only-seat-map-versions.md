# Seat Map Versions are append-only; rollback is duplicate-then-publish

Every save of a Seat Map appends a new immutable Version rather than mutating a working
row, and the Room points at one `published_version_id`. This gives the safety property
we need — editing the currently published map cannot change what attendees see until
someone publishes again — while also making the full edit history free. Publishing
always takes a map's newest Version; there is deliberately no "publish an older
Version" action.

## Considered Options

The previous design kept a mutable `draft` row paired with a `published` row per map,
with a publish dance that demoted the old published row back to `draft`. It worked, but
it made "published" a property of a row rather than a fact about the Room, left history
as an indistinguishable pile of rows named "Working Draft", and meant a catalogue would
have to explain a nested draft/published concept to users who only want to name a
layout and make it live.

We also considered letting the catalogue publish any chosen Version directly. We
rejected it because it makes `revision` ordering ambiguous — publish v3 after v7 and
"newest" no longer means "live" — and because the same outcome is reachable by
duplicating the old Version into a new map and publishing that, which additionally
leaves a named, auditable record of the rollback.

## Consequences

Rolling back mid-event is three actions (select version, Duplicate, Publish) rather than
one. Because duplication is the rollback path, Duplicate copies its source Version's
contents faithfully. Storage grows by one full `data` blob per save, which is acceptable
at this system's scale. Concurrent saves are rejected rather than merged: the editor
holds the revision it loaded and refuses to append if the map has moved on.
