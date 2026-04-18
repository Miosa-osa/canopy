## Define the Mox mock for the MIOSA client behaviour.
## Loaded in :test env via elixirc_paths (test/support).
Mox.defmock(Canopy.Miosa.MockClient, for: Canopy.Miosa.ClientBehaviour)
