# Start Wallaby for E2E browser tests
# Always start Wallaby, but tests are excluded by default via :wallaby tag
{:ok, _} = Application.ensure_all_started(:wallaby)
Application.put_env(:wallaby, :base_url, JargaWeb.Endpoint.url())

# Exclude evaluation tests by default
# To run evaluation tests: mix test --include evaluation
# Capture log output to suppress expected error messages in tests
ExUnit.start(exclude: [:evaluation, :wallaby], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)

# Note: Test users are created in FeatureCase setup, not here
# This is because we need proper database sandbox setup first

# Define mocks for testing
Mox.defmock(Jarga.Agents.Application.Services.LlmClientMock,
  for: Jarga.Agents.Infrastructure.Services.Behaviours.LlmClientBehaviour
)
