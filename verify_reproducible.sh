#!/usr/bin/env bash
# verify_reproducible.sh — a real reproducible-build verification gate.
#
# Compares a known-clean REFERENCE binary against the ARTIFACT a pipeline
# produced. If they differ, the artifact was influenced by something other than
# the source (e.g. a poisoned builder image) and MUST NOT ship.
#
# Usage:   verify_reproducible.sh <reference-binary> <artifact-binary>
# Exit 0:  byte-identical  → reproducible → safe to deploy
# Exit 1:  differ          → NOT reproducible → DEPLOY BLOCKED
#
# Wire this into a deploy gate. In this lab it is also used by CI to prove the
# defense detects the build-time backdoor.
set -euo pipefail

REF="${1:?usage: verify_reproducible.sh <reference-binary> <artifact-binary>}"
ART="${2:?usage: verify_reproducible.sh <reference-binary> <artifact-binary>}"

if [ ! -f "$REF" ]; then echo "reference not found: $REF" >&2; exit 2; fi
if [ ! -f "$ART" ]; then echo "artifact not found: $ART"  >&2; exit 2; fi

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

REF_HASH="$(sha256_of "$REF")"
ART_HASH="$(sha256_of "$ART")"

echo "reference ($REF): $REF_HASH"
echo "artifact  ($ART): $ART_HASH"

if [ "$REF_HASH" = "$ART_HASH" ]; then
  echo "PASS — reproducible build. Artifact matches the clean reference. Deploy allowed."
  exit 0
fi

echo "FAIL — NOT reproducible. Same source, different binary." >&2
echo "       The artifact was altered by the build environment. DEPLOY BLOCKED." >&2
exit 1
