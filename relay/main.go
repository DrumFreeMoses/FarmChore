package main

import (
	"log"
	"net/http"
	"os"
	"strings"
)

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	relay := NewRelay(os.Getenv("DATABASE_PATH"))
	defer relay.Close()

	webDir := os.Getenv("WEB_DIR")

	mux := http.NewServeMux()

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	if webDir != "" {
		fs := http.FileServer(http.Dir(webDir))
		mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			if r.Header.Get("Upgrade") == "websocket" {
				relay.HandleWebSocket(w, r)
				return
			}
			if r.URL.Path == "/" || r.URL.Path == "" {
				http.ServeFile(w, r, webDir+"/index.html")
				return
			}
			if !strings.Contains(r.URL.Path, ".") {
				http.ServeFile(w, r, webDir+"/index.html")
				return
			}
			fs.ServeHTTP(w, r)
		})
		log.Printf("Serving web from %s", webDir)
	} else {
		mux.HandleFunc("/", relay.HandleWebSocket)
	}

	log.Printf("FarmChore relay listening on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}
