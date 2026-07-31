package main

import "testing"

func TestCanonicalIDMatchesNIP01SpecExample(t *testing.T) {
	e := Event{
		ID:        "ba5cc5dc9b37809db7ad666da2826926641a24e5734327a245b43c5fe862e61f",
		PubKey:    "6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93",
		CreatedAt: 1673342637,
		Kind:      1,
		Tags:      [][]string{{"e", "3da979448d9ba263864c4d6f14997c079ba216ffa52b32a6ad98c8e6cdd3c1e6"}},
		Content:   "Hello world",
		Sig:       "a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2",
	}
	if got := e.CanonicalID(); got != e.ID {
		t.Errorf("canonical id = %s, want %s", got, e.ID)
	}
}

func TestValidate(t *testing.T) {
	valid := Event{
		ID:        "ba5cc5dc9b37809db7ad666da2826926641a24e5734327a245b43c5fe862e61f",
		PubKey:    "6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93",
		CreatedAt: 1673342637,
		Kind:      1,
		Tags:      [][]string{{"e", "3da979448d9ba263864c4d6f14997c079ba216ffa52b32a6ad98c8e6cdd3c1e6"}},
		Content:   "Hello world",
		Sig:       "a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2",
	}
	if err := valid.Validate(); err != nil {
		t.Fatalf("valid event rejected: %v", err)
	}

	tampered := valid
	tampered.Content = "Hello world!"
	if err := tampered.Validate(); err == nil {
		t.Error("tampered content with stale id accepted")
	}

	badPub := valid
	badPub.ID = badPub.CanonicalID()
	badPub.PubKey = "zzzz"
	if err := badPub.Validate(); err == nil {
		t.Error("non-hex pubkey accepted")
	}
}
