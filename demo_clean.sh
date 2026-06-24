#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/build_clean"

mkdir -p "$OUTPUT_DIR"

echo ""
echo " CLEAN BUILD — Source code only"
echo ""
cd "$SCRIPT_DIR/clean_app"

echo "[1/2] Compiling clean application..."
GOOS=$(uname -s | tr '[:upper:]' '[:lower:]')           # darwin on macOS, linux on Linux
GOARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')
docker run --rm \
    -e GOOS="$GOOS" \
    -e GOARCH="$GOARCH" \
    -e CGO_ENABLED=0 \
    -v "$SCRIPT_DIR/clean_app":/app \
    -w /app \
    golang:1.22-alpine \
    go build -buildvcs=false -o /app/server .
mv "$SCRIPT_DIR/clean_app/server" "$OUTPUT_DIR/server"
echo "      Binary: $OUTPUT_DIR/server"
echo ""

echo "[2/2] Starting clean server on http://localhost:8080"
echo ""
echo "  Open http://localhost:8080 in your browser"
echo "  Try: curl http://localhost:8080/__backdoor__"
echo "       (should return 404 — backdoor does not exist)"
echo ""

export PORT=8080
exec "$OUTPUT_DIR/server"
