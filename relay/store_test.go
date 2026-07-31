package main

import "testing"

func testEvent(id string, kind int) *Event {
	e := &Event{
		ID:        id,
		PubKey:    "6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93",
		CreatedAt: 1673342637,
		Kind:      kind,
		Content:   "hello " + id[:8],
		Sig:       "a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2",
	}
	e.ID = e.CanonicalID()
	return e
}

func TestStoreSaveAndDedupe(t *testing.T) {
	s, err := NewStore(":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()

	e := testEvent("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 31501)
	ok, err := s.Save(e)
	if err != nil || !ok {
		t.Fatalf("first save: ok=%v err=%v", ok, err)
	}
	ok, err = s.Save(e)
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Error("duplicate save reported as new")
	}
}

func TestStoreQueryByKindAndAuthor(t *testing.T) {
	s, _ := NewStore(":memory:")
	defer s.Close()

	a := testEvent("1111111111111111111111111111111111111111111111111111111111111111", 31501)
	b := testEvent("2222222222222222222222222222222222222222222222222222222222222222", 31502)
	s.Save(a)
	s.Save(b)

	got, err := s.Query(Filter{Kinds: []int{31501}})
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 || got[0].ID != a.ID {
		t.Errorf("kind query = %+v", got)
	}

	got, err = s.Query(Filter{Authors: []string{a.PubKey}, Since: 1})
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 {
		t.Errorf("author query = %d events, want 2", len(got))
	}

	got, err = s.Query(Filter{IDs: []string{a.ID}})
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 {
		t.Errorf("id query = %d events", len(got))
	}
}

func TestStoreQueryTagFilter(t *testing.T) {
	s, _ := NewStore(":memory:")
	defer s.Close()

	milker := "milker-pubkey"
	e := testEvent("3333333333333333333333333333333333333333333333333333333333333333", 31500)
	e.Tags = [][]string{{"role", milker}}
	s.Save(e)

	got, err := s.Query(Filter{Tags: map[string][]string{"role": {milker}}})
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 {
		t.Errorf("tag query = %d events, want 1", len(got))
	}

	got, err = s.Query(Filter{Tags: map[string][]string{"role": {"nobody"}}})
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 0 {
		t.Errorf("non-matching tag query = %d events, want 0", len(got))
	}
}
