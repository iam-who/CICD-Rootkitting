#!/bin/bash
# build_and_inject.sh
# Builds the "compromised" binary using the poisoned company/go-builder image.
# This simulates what a compromised CI runner does — source never touched.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT="$REPO_ROOT/build_compromised/server"

mkdir -p "$REPO_ROOT/build_compromised"

echo "[*] Building with company/go-builder:latest (the compromised runner image)..."
echo "[*] Source tree: CLEAN — no changes made to repo"
echo ""

GOOS=$(uname -s | tr '[:upper:]' '[:lower:]')           # darwin on macOS, linux on Linux
GOARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')
docker run --rm \
    -e GOOS="$GOOS" \
    -e GOARCH="$GOARCH" \
    -e CGO_ENABLED=0 \
    -v "$REPO_ROOT/clean_app":/app \
    -w /app \
    --entrypoint /bin/sh \
    company/go-builder:latest \
    -c "go build -buildvcs=false -o /app/server . && echo '[*] Build complete'"

# Move the output to build_compromised/
mv "$REPO_ROOT/clean_app/server" "$OUTPUT"

echo "[*] Compromised binary at: $OUTPUT"
