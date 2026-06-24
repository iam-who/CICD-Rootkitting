#!/bin/bash
# setup.sh — one-time setup: builds the poisoned runner image and initialises git
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  CI/CD Rootkit Lab — Setup (builds run inside Docker)          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# ── 1. Check dependencies ──────────────────────────────────────────────────
for dep in docker git; do
    if ! command -v "$dep" &>/dev/null; then
        echo "ERROR: '$dep' not found. Please install it first."
        exit 1
    fi
done
echo "[✓] Dependencies: docker, git"

# ── 2. Build the poisoned Docker image ────────────────────────────────────
echo ""
echo "[*] Building company/go-builder:latest (the poisoned runner image)..."
echo "    Context: compromised_runner/"
echo ""
docker build \
    -t company/go-builder:latest \
    -f "$SCRIPT_DIR/compromised_runner/Dockerfile.builder" \
    "$SCRIPT_DIR/compromised_runner/"
echo ""
echo "[✓] company/go-builder:latest built"

# ── 3. Init git in clean_app (for the 'pristine source' story) ────────────
cd "$SCRIPT_DIR/clean_app"
if [ ! -d ".git" ]; then
    git init -q
    git config user.email "dev@example.com"
    git config user.name "Developer"
    git add go.mod main.go templates/index.html .github/
    git commit -q -m "feat: initial release — clean API server v1.0.0"
    echo "[✓] Git repo initialised in clean_app/ (pristine history)"
else
    echo "[✓] Git repo already exists in clean_app/"
fi

# ── 4. Build clean reference binary ───────────────────────────────────────
cd "$SCRIPT_DIR/clean_app"
mkdir -p "$SCRIPT_DIR/build_clean"
echo ""
echo "[*] Building clean reference binary (official golang:1.22-alpine)..."
GOOS=$(uname -s | tr '[:upper:]' '[:lower:]')           # darwin on macOS, linux on Linux
GOARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')
docker run --rm \
    -e GOOS="$GOOS" \
    -e GOARCH="$GOARCH" \
    -e CGO_ENABLED=0 \
    -v "$SCRIPT_DIR/clean_app":/app \
    -w /app \
    golang:1.22-alpine \
    sh -c "go build -buildvcs=false -o /app/server . && echo '[*] Clean build done'"
mv "$SCRIPT_DIR/clean_app/server" "$SCRIPT_DIR/build_clean/server"
echo "[✓] Clean binary: build_clean/server"

# ── 5. Build compromised binary ───────────────────────────────────────────
echo ""
echo "[*] Building compromised binary (company/go-builder:latest)..."
bash "$SCRIPT_DIR/compromised_runner/build_and_inject.sh"
echo "[✓] Compromised binary: build_compromised/server"

# ── 6. Make scripts executable ────────────────────────────────────────────
chmod +x "$SCRIPT_DIR"/*.sh
chmod +x "$SCRIPT_DIR/compromised_runner/build_and_inject.sh"

# ── 7. Hash comparison preview ────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  VERIFICATION"
echo "══════════════════════════════════════════════════════════════════"
CLEAN_HASH=$(sha256sum "$SCRIPT_DIR/build_clean/server" | cut -d' ' -f1)
BAD_HASH=$(sha256sum "$SCRIPT_DIR/build_compromised/server" | cut -d' ' -f1)
echo "  Clean binary hash:        ${CLEAN_HASH:0:32}..."
echo "  Compromised binary hash:  ${BAD_HASH:0:32}..."
if [ "$CLEAN_HASH" != "$BAD_HASH" ]; then
    echo ""
    echo "  ✓ Binaries differ — same source, different binary. Demo ready."
else
    echo ""
    echo "  ✗ WARNING: Binaries are identical — injection may not have worked."
fi

echo ""
echo "Setup complete! Run the demo:"
echo "  ./demo_compare.sh   ← full live demo (recommended)"
echo "  ./demo_clean.sh     ← clean server only (port 8080)"
echo "  ./demo_compromised.sh ← backdoored server only (port 8081)"
