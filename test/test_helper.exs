ExUnit.start()

# Default the shared settings row to "setup complete" so existing tests exercise the
# app in its served state. Onboarding tests flip it to :not_started within their own
# sandboxed transaction. Runs while the sandbox is still in :auto mode.
Lanpartyseating.Repo.get(Lanpartyseating.Setting, 1)
|> Kernel.||(%Lanpartyseating.Setting{id: 1})
|> Ecto.Changeset.change(setup_state: :complete)
|> Lanpartyseating.Repo.insert_or_update!()

Ecto.Adapters.SQL.Sandbox.mode(Lanpartyseating.Repo, :manual)
