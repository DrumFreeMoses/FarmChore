package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"

	"github.com/gorilla/websocket"
)

// Relay is a minimal NIP-01 relay.
type Relay struct {
	store *Store
	up    websocket.Upgrader
	apiKey string

	mu      sync.Mutex
	clients map[*client]bool
}

type client struct {
	conn   *websocket.Conn
	relay  *Relay
	send   chan []byte
	subs   map[string]struct{}
}

func NewRelay(path string) *Relay {
	store, err := NewStore(path)
	if err != nil {
		log.Fatalf("open store: %v", err)
	}
	r := &Relay{
		store:   store,
		apiKey:  os.Getenv("API_KEY"),
		clients: map[*client]bool{},
		up: websocket.Upgrader{
			CheckOrigin: func(*http.Request) bool { return true },
		},
	}
	return r
}

func (r *Relay) Close() { r.store.Close() }

func (r *Relay) HandleWebSocket(w http.ResponseWriter, req *http.Request) {
	// Authenticate if API_KEY is configured.
	if r.apiKey != "" {
		key := req.URL.Query().Get("key")
		if key == "" {
			// Also check Authorization header.
			key = req.Header.Get("Authorization")
			key = strings.TrimPrefix(key, "Bearer ")
		}
		if key != r.apiKey {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
	}

	conn, err := r.up.Upgrade(w, req, nil)
	if err != nil {
		log.Printf("upgrade: %v", err)
		return
	}
	c := &client{conn: conn, relay: r, send: make(chan []byte, 64), subs: map[string]struct{}{}}
	r.mu.Lock()
	r.clients[c] = true
	r.mu.Unlock()
	go c.writePump()
	c.readPump()
}

// broadcast pushes an event to every subscribed client.
func (r *Relay) broadcast(e *Event) {
	payload, _ := json.Marshal([]any{"EVENT", e})
	r.mu.Lock()
	defer r.mu.Unlock()
	for c := range r.clients {
		if c.subscribedTo(e) {
			select {
			case c.send <- payload:
			default:
				// drop for slow client; keep relay healthy
			}
		}
	}
}

func (c *client) subscribedTo(e *Event) bool {
	for range c.subs {
		return true
	}
	return false
}

func (c *client) writePump() {
	defer func() {
		c.conn.Close()
		c.relay.mu.Lock()
		delete(c.relay.clients, c)
		c.relay.mu.Unlock()
	}()
	for msg := range c.send {
		if err := c.conn.WriteMessage(websocket.TextMessage, msg); err != nil {
			return
		}
	}
}

func (c *client) sendOK(id string, ok bool, msg string) {
	payload, _ := json.Marshal([]any{"OK", id, ok, msg})
	c.send <- payload
}

func (c *client) sendNotice(msg string) {
	payload, _ := json.Marshal([]any{"NOTICE", msg})
	c.send <- payload
}

func (c *client) readPump() {
	defer func() {
		c.conn.Close()
		c.relay.mu.Lock()
		delete(c.relay.clients, c)
		c.relay.mu.Unlock()
	}()
	for {
		_, data, err := c.conn.ReadMessage()
		if err != nil {
			return
		}
		var msg []json.RawMessage
		if err := json.Unmarshal(data, &msg); err != nil || len(msg) < 2 {
			c.sendNotice("malformed message")
			continue
		}
		var typ string
		if err := json.Unmarshal(msg[0], &typ); err != nil {
			continue
		}
		switch typ {
		case "EVENT":
			c.handleEvent(msg)
		case "REQ":
			c.handleReq(msg)
		case "CLOSE":
			c.handleClose(msg)
		default:
			c.sendNotice("unknown message type")
		}
	}
}
