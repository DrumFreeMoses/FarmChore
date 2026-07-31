package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func newTestRelay(t *testing.T) (*Relay, *httptest.Server) {
	t.Helper()
	r := NewRelay(":memory:")
	srv := httptest.NewServer(http.HandlerFunc(r.HandleWebSocket))
	t.Cleanup(func() {
		srv.Close()
		r.Close()
	})
	return r, srv
}

func dial(t *testing.T, srv *httptest.Server) *websocket.Conn {
	t.Helper()
	wsURL := "ws" + srv.URL[4:]
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close() })
	return conn
}

func readMsg(t *testing.T, conn *websocket.Conn) []json.RawMessage {
	t.Helper()
	conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, data, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	var msg []json.RawMessage
	if err := json.Unmarshal(data, &msg); err != nil {
		t.Fatalf("bad message: %s", data)
	}
	return msg
}

func TestEventRoundTrip(t *testing.T) {
	_, srv := newTestRelay(t)
	conn := dial(t, srv)

	e := testEvent("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 31501)
	conn.WriteJSON([]any{"EVENT", e})

	msg := readMsg(t, conn)
	var typ string
	json.Unmarshal(msg[0], &typ)
	if typ != "OK" {
		t.Fatalf("expected OK, got %s (%s)", typ, msg)
	}
	var ok bool
	json.Unmarshal(msg[2], &ok)
	if !ok {
		t.Fatalf("event rejected: %s", msg[3])
	}
}

func TestRejectInvalidEvent(t *testing.T) {
	_, srv := newTestRelay(t)
	conn := dial(t, srv)

	e := testEvent("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 31501)
	e.Content = "tampered" // stale id
	conn.WriteJSON([]any{"EVENT", e})

	msg := readMsg(t, conn)
	var ok bool
	json.Unmarshal(msg[2], &ok)
	if ok {
		t.Fatal("invalid event accepted")
	}
}

func TestReqEoseSequence(t *testing.T) {
	r, srv := newTestRelay(t)
	writer := dial(t, srv)

	e := testEvent("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", 31501)
	writer.WriteJSON([]any{"EVENT", e})
	if msg := readMsg(t, writer); string(msg[0]) != `"OK"` {
		t.Fatalf("expected OK, got %s", msg[0])
	}

	reader := dial(t, srv)
	reader.WriteJSON([]any{"REQ", "sub1", map[string]any{"kinds": []int{31501}}})
	msg := readMsg(t, reader)
	var typ string
	json.Unmarshal(msg[0], &typ)
	if typ != "EVENT" {
		t.Fatalf("expected EVENT, got %s", msg[0])
	}
	var subID string
	json.Unmarshal(msg[1], &subID)
	if subID != "sub1" {
		t.Fatalf("wrong subscription id: %s", subID)
	}
	msg = readMsg(t, reader)
	json.Unmarshal(msg[0], &typ)
	if typ != "EOSE" {
		t.Fatalf("expected EOSE, got %s", msg[0])
	}

	// live broadcast: a NEW event reaches the subscribed reader
	fresh := testEvent("cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", 31501)
	writer.WriteJSON([]any{"EVENT", fresh})
	if msg := readMsg(t, writer); string(msg[0]) != `"OK"` {
		t.Fatalf("expected OK, got %s", msg[0])
	}
	msg = readMsg(t, reader)
	json.Unmarshal(msg[0], &typ)
	if typ != "EVENT" {
		t.Fatalf("expected live EVENT, got %s", msg[0])
	}

	r.mu.Lock()
	_ = len(r.clients)
	r.mu.Unlock()
}
