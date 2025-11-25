#!/bin/bash
# Run Wallaby tests with visible browser for debugging
#
# Usage:
#   ./scripts/run-wallaby-visible.sh                           # Run all wallaby tests
#   ./scripts/run-wallaby-visible.sh test/path/to/test.exs    # Run specific test
#   ./scripts/run-wallaby-visible.sh test/path/to/test.exs:43 # Run specific test at line 43

set -e

echo "🌐 Running Wallaby tests with visible browser..."
echo ""

# Load API key from .env if it exists
if [ -f .env ]; then
  export $(grep "^OPENROUTER_API_KEY=" .env | xargs)
  if [ -n "$OPENROUTER_API_KEY" ]; then
    echo "✅ Loaded OpenRouter API key from .env"
  else
    echo "⚠️  Warning: OPENROUTER_API_KEY not found in .env"
  fi
fi

# Set environment variables
export WALLABY_HEADED=true
export MIX_ENV=test

# Determine which tests to run
if [ -z "$1" ]; then
  TEST_PATH="--only wallaby"
  echo "📋 Running all Wallaby tests"
else
  TEST_PATH="$1 --only wallaby"
  echo "📋 Running: $1"
fi

echo ""
echo "💡 Tips:"
echo "  - Browser window will open automatically"
echo "  - Watch the actions happen in real-time"
echo "  - Screenshots saved to tmp/screenshots/"
echo "  - Press Ctrl+C to stop"
echo ""

# Run the tests
mix test $TEST_PATH --trace

echo ""
echo "✅ Tests complete!"
echo "📸 Screenshots available in: tmp/screenshots/"
