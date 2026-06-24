package main

import (
	"embed"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"time"
)

//go:embed templates/*
var templateFS embed.FS

var (
	hostname string
	tmpl     *template.Template
)

type PageData struct {
	Version   string
	BuildTime string
	Hostname  string
	Status    string
	Endpoints []Endpoint
}

type Endpoint struct {
	Path        string
	Method      string
	Description string
	Status      string
}

func init() {
	hostname, _ = os.Hostname()

	funcMap := template.FuncMap{
		"lower": func(s string) string {
			if len(s) < 1 {
				return s
			}
			return string(s[0]+32) + s[1:]
		},
	}
	tmpl = template.Must(
		template.New("index.html").Funcs(funcMap).ParseFS(templateFS, "templates/index.html"),
	)
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	data := PageData{
		Version:   "1.0.0",
		BuildTime: time.Now().Format(time.RFC3339),
		Hostname:  hostname,
		Status:    "All systems operational",
		Endpoints: []Endpoint{
			{"/health", "GET", "Health check", "200 OK"},
			{"/api/users", "GET", "List users", "200 OK"},
			{"/api/status", "GET", "System status", "200 OK"},
			{"/login", "POST", "User authentication", "200 OK"},
		},
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	tmpl.Execute(w, data)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"status":"healthy","version":"1.0.0","hostname":"%s"}`, hostname)
}

func usersHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"users":[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}],"count":2}`)
}

func statusHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"uptime":"72h14m","connections":42,"cpu":"12%%","memory":"34%%"}`)
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"message":"Login successful","token":"eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."}`)
}

// registerRoutes wires the application handlers onto the given mux. The live
// server uses the default mux (passing nil to ListenAndServe) so that any code
// injected via an init() — like the build-time backdoor in this lab — is also
// served; tests call the handlers directly.
func registerRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/", indexHandler)
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/api/users", usersHandler)
	mux.HandleFunc("/api/status", statusHandler)
	mux.HandleFunc("/login", loginHandler)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	registerRoutes(http.DefaultServeMux)

	// Safety boundary: bind to loopback only so this lab server is never
	// exposed on the network. Override with LAB_BIND_ALL=1 only if you
	// understand the risk (the compromised build contains a backdoor).
	host := "127.0.0.1"
	if os.Getenv("LAB_BIND_ALL") == "1" {
		host = ""
	}
	addr := host + ":" + port

	log.Printf("Server starting on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
