package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
)

// Event is a NIP-01 event.
type Event struct {
	ID        string     `json:"id"`
	PubKey    string     `json:"pubkey"`
	CreatedAt int64      `json:"created_at"`
	Kind      int        `json:"kind"`
	Tags      [][]string `json:"tags"`
	Content   string     `json:"content"`
	Sig       string     `json:"sig"`
}

// CanonicalID computes the NIP-01 event id: sha256 of the canonical
// serialization [0, pubkey, created_at, kind, tags, content].
func (e *Event) CanonicalID() string {
	var sb strings.Builder
	sb.WriteString(`[0,"`)
	sb.WriteString(e.PubKey)
	sb.WriteString(`",`)
	fmt.Fprintf(&sb, "%d", e.CreatedAt)
	sb.WriteString(",")
	fmt.Fprintf(&sb, "%d", e.Kind)
	sb.WriteString(",")
	tags, _ := json.Marshal(e.Tags)
	sb.Write(tags)
	sb.WriteString(",")
	content, _ := json.Marshal(e.Content)
	sb.Write(content)
	sb.WriteString("]")
	sum := sha256.Sum256([]byte(sb.String()))
	return hex.EncodeToString(sum[:])
}

// Validate checks shape and event id; returns a NOTICE-worthy error message.
func (e *Event) Validate() error {
	if len(e.PubKey) != 64 || !isHex(e.PubKey) {
		return errors.New("pubkey must be a 64-char hex string")
	}
	if len(e.Sig) != 128 || !isHex(e.Sig) {
		return errors.New("sig must be a 128-char hex string")
	}
	if e.CreatedAt < 0 {
		return errors.New("created_at must not be negative")
	}
	if e.Kind < 0 {
		return errors.New("kind must not be negative")
	}
	if e.ID != e.CanonicalID() {
		return errors.New("invalid event id")
	}
	return nil
}

func isHex(s string) bool {
	for _, c := range s {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f' || c >= 'A' && c <= 'F') {
			return false
		}
	}
	return true
}
