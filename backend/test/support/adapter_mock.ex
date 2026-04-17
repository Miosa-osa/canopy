## Define the Mox mock for the Adapter behaviour.
## This is loaded by elixirc_paths in :test env (test/support).
Mox.defmock(Canopy.Runtimes.MockAdapter, for: Canopy.Runtimes.Adapter)
