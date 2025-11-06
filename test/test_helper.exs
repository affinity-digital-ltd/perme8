# Exclude evaluation tests by default
# To run evaluation tests: mix test --include evaluation
ExUnit.start(exclude: [:evaluation])

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
