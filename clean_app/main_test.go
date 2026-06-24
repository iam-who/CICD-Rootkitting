package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// The clean application must expose exactly the documented endpoints and
// nothing else. These tests are the source-level guarantee that the repo is
// clean — the whole point of the lab is that the binary can still differ.

func TestHealthHandler(t *testing.T) {
	rr := httptest.NewRecorder()
	healthHandler(rr, httptest.NewRequest(http.MethodGet, "/health", nil))

	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rr.Code)
	}
	var body map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &body); err != nil {
		t.Fatalf("response is not valid JSON: %v", err)
	}
	if body["status"] != "healthy" {
		t.Errorf("status = %v, want healthy", body["status"])
	}
}

func TestUsersHandler(t *testing.T) {
	rr := httptest.NewRecorder()
	usersHandler(rr, httptest.NewRequest(http.MethodGet, "/api/users", nil))

	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rr.Code)
	}
	if ct := rr.Header().Get("Content-Type"); ct != "application/json" {
		t.Errorf("content-type = %q, want application/json", ct)
	}
}

func TestLoginRejectsGet(t *testing.T) {
	rr := httptest.NewRecorder()
	loginHandler(rr, httptest.NewRequest(http.MethodGet, "/login", nil))

	if rr.Code != http.StatusMethodNotAllowed {
		t.Errorf("GET /login status = %d, want 405", rr.Code)
	}
}

func TestLoginAcceptsPost(t *testing.T) {
	rr := httptest.NewRecorder()
	loginHandler(rr, httptest.NewRequest(http.MethodPost, "/login", nil))

	if rr.Code != http.StatusOK {
		t.Errorf("POST /login status = %d, want 200", rr.Code)
	}
}

func TestIndexUnknownPathIs404(t *testing.T) {
	rr := httptest.NewRecorder()
	indexHandler(rr, httptest.NewRequest(http.MethodGet, "/does-not-exist", nil))

	if rr.Code != http.StatusNotFound {
		t.Errorf("unknown path status = %d, want 404", rr.Code)
	}
}

// TestNoBackdoorRouteInCleanBinary asserts that the application, built from this
// source alone, exposes no hidden endpoint. When the SAME source is compiled by
// the poisoned builder image, this guarantee no longer holds at runtime — which
// is exactly the supply-chain gap the lab demonstrates.
func TestNoBackdoorRouteInCleanBinary(t *testing.T) {
	mux := http.NewServeMux()
	registerRoutes(mux)

	for _, path := range []string{"/__backdoor__", "/admin", "/debug/exec"} {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		req.Header.Set("X-Backdoor-Token", "secret")
		_, pattern := mux.Handler(req)
		if pattern != "" && !strings.HasPrefix(pattern, "/") {
			continue
		}
		// The catch-all "/" handler returns 404 for unknown paths; a dedicated
		// backdoor route would resolve to its own non-"/" pattern.
		if pattern != "" && pattern != "/" {
			t.Errorf("clean build unexpectedly routes %s to pattern %q", path, pattern)
		}
	}
}
