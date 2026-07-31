package main

import "testing"

func TestFilterMatches(t *testing.T) {
	e := Event{
		ID:        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		PubKey:    "6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93",
		CreatedAt: 100,
		Kind:      31501,
		Content:   "feed the pigs",
		Tags:      [][]string{{"role", "Feeders"}, {"date", "2026-07-31"}},
	}

	if !(Filter{Kinds: []int{31501}, Limit: 10}).Matches(&e) {
		t.Error("kind filter should match")
	}
	if (Filter{Kinds: []int{31500}}).Matches(&e) {
		t.Error("wrong kind matched")
	}
	if !(Filter{Authors: []string{e.PubKey}}).Matches(&e) {
		t.Error("author filter should match")
	}
	if (Filter{Since: 101}).Matches(&e) {
		t.Error("since filter should reject")
	}
	if !(Filter{Tags: map[string][]string{"role": {"Feeders"}}}).Matches(&e) {
		t.Error("role tag should match")
	}
	if (Filter{Tags: map[string][]string{"role": {"Milkers"}}}).Matches(&e) {
		t.Error("wrong role tag matched")
	}
	if !(Filter{Tags: map[string][]string{"date": {"2026-07-31"}}, Kinds: []int{31501}}).Matches(&e) {
		t.Error("combined filter should match")
	}
}

func TestFilterUnmarshalTagKeys(t *testing.T) {
	var f Filter
	if err := jsonUnmarshal([]byte(`{"kinds":[31501],"#role":["Feeders"]}`), &f); err != nil {
		t.Fatal(err)
	}
	if len(f.Kinds) != 1 || f.Kinds[0] != 31501 {
		t.Errorf("kinds = %v", f.Kinds)
	}
	if got := f.Tags["role"]; len(got) != 1 || got[0] != "Feeders" {
		t.Errorf("tags = %v", f.Tags)
	}
}
