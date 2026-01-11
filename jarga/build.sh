#!/usr/bin/env bash
# exit on error
set -o errexit

# Install dependencies
mix deps.get --only prod

# Install npm dependencies for assets
cd assets && npm install && cd ..

# Compile the application
MIX_ENV=prod mix compile

# Build assets
MIX_ENV=prod mix assets.build
MIX_ENV=prod mix assets.deploy

# Generate release wrapper scripts
MIX_ENV=prod mix phx.gen.release

# Create the release
MIX_ENV=prod mix release --overwrite
