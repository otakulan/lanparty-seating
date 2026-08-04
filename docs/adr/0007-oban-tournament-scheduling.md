# Tournament start/end scheduling runs on Oban

Tournament start and end were driven by `restart: :transient` GenServers that slept with
`Process.send_after` and broadcast on fire. That design is fragile: `send_after` is capped at
~49.7 days, the timing state lives only in the process heap, and on a crash the kickstarter
only restarted the *start* task for tournaments whose `start_date` was still in the future —
so an in-progress tournament was never re-broadcast after a restart. We moved start/end
scheduling to Oban, where jobs are persisted in Postgres, survive restarts by construction,
and re-fire (or are visible as pending) on boot. Reservation-expiry scheduling is left on its
existing GenServer path; only tournaments moved, keeping the dependency surface small.

## Considered Options

Keeping the GenServers but making them "DB-backed and self-healing" (recompute all
now→future tournaments on boot and restart both tasks) was the lighter touch and would have
fixed the crash-recovery gap. We chose Oban instead because the user wanted the scheduling
state to live in a redundant store rather than process memory, and because a real job queue
gives observability (a dashboard, retries, job tags for deletion) for free. The cost is a new
dependency and a different execution model, accepted as worth it for the crash-safety.
