#!/usr/bin/env bash
# tests/run_tests.sh — integration tests for the CI/CD rootkit lab.
#
# Asserts the core invariants of the lab end to end:
#   1. the source tree is clean (no backdoor in any .go file)
#   2. the clean and compromised binaries are NOT reproducible (hashes differ)
#   3. the backdoor string is in the compromised binary only
#   4. at runtime: clean server hides the route, compromised server serves it
#   5. RCE is a dry-run by default and only executes with LAB_ALLOW_RCE=1
#
# Requires both binaries to exist (run `bash setup.sh` first).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLEAN_BIN="$ROOT/build_clean/server"
BAD_BIN="$ROOT/build_compromised/server"
TOKEN="${LAB_BACKDOOR_TOKEN:-secret}"

pass=0; fail=0
ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

echo "── Static checks ──────────────────────────────────────────────"
# Scan application source only (test files legitimately reference the route to
# assert its absence) — this is the same scope a SAST gate would use.
check "application source has no backdoor in any .go file" \
  '! grep -rq "__backdoor__" "$ROOT/clean_app" --include="*.go" --exclude="*_test.go"'
check "both binaries exist" '[ -f "$CLEAN_BIN" ] && [ -f "$BAD_BIN" ]'
check "reproducible-build gate BLOCKS the tampered artifact" \
  '! bash "$ROOT/verify_reproducible.sh" "$CLEAN_BIN" "$BAD_BIN" >/dev/null 2>&1'
# Precompute strings to temp files: `strings | grep -q` would trip SIGPIPE under
# `set -o pipefail` once grep matches and closes the pipe.
strings "$BAD_BIN"   > /tmp/lab_bad.strings   2>/dev/null || true
strings "$CLEAN_BIN" > /tmp/lab_clean.strings 2>/dev/null || true
check "backdoor string present in compromised binary" \
  'grep -q "__backdoor__" /tmp/lab_bad.strings'
check "backdoor string ABSENT from clean binary" \
  '! grep -q "__backdoor__" /tmp/lab_clean.strings'

echo "── Runtime checks (loopback only) ─────────────────────────────"
# free ports, start both servers
for p in 8080 8081; do lsof -ti:$p 2>/dev/null | xargs kill 2>/dev/null; done
PORT=8080 "$CLEAN_BIN" >/tmp/lab_clean.log 2>&1 &  CPID=$!
PORT=8081 "$BAD_BIN"   >/tmp/lab_bad.log   2>&1 &  BPID=$!
# compromised server with RCE explicitly enabled, on a third port
PORT=8082 LAB_ALLOW_RCE=1 "$BAD_BIN" >/tmp/lab_rce.log 2>&1 & RPID=$!
sleep 1.5

code(){ curl -s -o /dev/null -w '%{http_code}' "$@"; }

check "clean server: homepage is 200" '[ "$(code http://127.0.0.1:8080/)" = 200 ]'
check "clean server: /__backdoor__ is 404" \
  '[ "$(code http://127.0.0.1:8080/__backdoor__)" = 404 ]'
check "compromised server: no token → 404" \
  '[ "$(code http://127.0.0.1:8081/__backdoor__)" = 404 ]'
check "compromised server: valid token → backdoor_active" \
  'curl -s -H "X-Backdoor-Token: $TOKEN" http://127.0.0.1:8081/__backdoor__ | grep -q backdoor_active'
check "RCE is a dry-run by default (rce_disabled)" \
  'curl -s -H "X-Backdoor-Token: $TOKEN" "http://127.0.0.1:8081/__backdoor__?cmd=id" | grep -q rce_disabled'
check "RCE executes only with LAB_ALLOW_RCE=1" \
  'curl -s -H "X-Backdoor-Token: $TOKEN" "http://127.0.0.1:8082/__backdoor__?cmd=id" | grep -q "uid="'

kill "$CPID" "$BPID" "$RPID" 2>/dev/null
wait "$CPID" "$BPID" "$RPID" 2>/dev/null   # collect exits so the shell stays quiet
for p in 8080 8081 8082; do lsof -ti:$p 2>/dev/null | xargs kill 2>/dev/null; done

echo "───────────────────────────────────────────────────────────────"
echo "PASS: $pass   FAIL: $fail"
[ "$fail" -eq 0 ] || exit 1
