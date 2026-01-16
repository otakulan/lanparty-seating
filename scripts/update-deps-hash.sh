#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Save the current hash
current_hash=$(grep -oP 'hash = "\K[^"]+' default.nix)

# Temporarily set a fake hash to trigger rebuild and get the correct hash
sed -i 's|hash = "sha256-[^"]*"|hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="|' default.nix

# Run build and capture the correct hash from error output
echo "Fetching new hash (this will show an expected error)..."
new_hash=$(nix build '.#lanparty-seating' 2>&1 | grep -oP 'got:\s+\K\S+' || true)

if [ -n "$new_hash" ]; then
  echo "New hash: $new_hash"
  sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"$new_hash\"|" default.nix
  echo "Updated default.nix with new hash"
else
  # Restore original hash if we couldn't get a new one
  sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"$current_hash\"|" default.nix
  echo "Could not determine new hash - restored original"
  exit 1
fi
