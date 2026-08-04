# Tournaments are Seat-backed, not station-backed

A Tournament Hold claims Seats by `seat_slot_id`, retiring the legacy `stations` path
(`tournament_reservations.station_id`). Previously holds were written only against
`station_id`, so the seat map runtime — which reads holds by `seat_slot_id` — never saw
them: tournament holds were invisible on `/`, `/map` and `/kiosk`, and did not participate
in the publish-safety guard. Editor-created Seats (nil `legacy_station_number`) were
unaddressable by the desktop client. Holding by `seat_slot_id` fixes visibility, makes holds
correctly block publishing, makes the "underway" check meaningful, and lets the desktop
signal address PCs by `pc_asset.remote_identifier` (which every Seat has). The legacy
`stations` table remains only for the pre-catalogue grid; tournament code no longer touches
it.
