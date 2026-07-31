package main

import (
	"encoding/json"
	"errors"
	"strings"
)

// Filter is a NIP-01 subscription filter.
type Filter struct {
	IDs     []string          `json:"ids"`
	Kinds   []int             `json:"kinds"`
	Authors []string          `json:"authors"`
	Since   int64             `json:"since,omitempty"`
	Until   int64             `json:"until,omitempty"`
	Limit   int               `json:"limit,omitempty"`
	Tags    map[string][]string `json:"-"`
}

// UnmarshalJSON extracts both the named fields and "#<tagname>" keys.
func (f *Filter) UnmarshalJSON(data []byte) error {
	type alias Filter
	var raw struct {
		alias
		Tags map[string][]string `json:"-"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	*f = Filter(raw.alias)
	var generic map[string]json.RawMessage
	if err := json.Unmarshal(data, &generic); err != nil {
		return err
	}
	f.Tags = map[string][]string{}
	for k, v := range generic {
		if strings.HasPrefix(k, "#") && len(k) > 1 {
			var vals []string
			if err := json.Unmarshal(v, &vals); err != nil {
				return err
			}
			f.Tags[k[1:]] = vals
		}
	}
	return nil
}

var errEmptyFilter = errors.New("empty filter")

// Matches reports whether the event satisfies the filter.
func (f Filter) Matches(e *Event) bool {
	if len(f.IDs) > 0 && !contains(f.IDs, e.ID) {
		return false
	}
	if len(f.Kinds) > 0 && !containsInt(f.Kinds, e.Kind) {
		return false
	}
	if len(f.Authors) > 0 && !contains(f.Authors, e.PubKey) {
		return false
	}
	if f.Since > 0 && e.CreatedAt < f.Since {
		return false
	}
	if f.Until > 0 && e.CreatedAt > f.Until {
		return false
	}
	for tag, values := range f.Tags {
		ok := false
		for _, t := range e.Tags {
			if len(t) >= 2 && t[0] == tag && contains(values, t[1]) {
				ok = true
				break
			}
		}
		if !ok {
			return false
		}
	}
	return true
}

func contains(hay []string, needle string) bool {
	for _, s := range hay {
		if s == needle {
			return true
		}
	}
	return false
}

func containsInt(hay []int, needle int) bool {
	for _, n := range hay {
		if n == needle {
			return true
		}
	}
	return false
}
