package main

import (
	"database/sql"
	"log"
	"time"

	_ "modernc.org/sqlite"
)

// Store persists events in SQLite.
type Store struct {
	db *sql.DB
}

func NewStore(path string) (*Store, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS events (
		id TEXT PRIMARY KEY,
		pubkey TEXT NOT NULL,
		kind INTEGER NOT NULL,
		created_at INTEGER NOT NULL,
		content TEXT NOT NULL,
		sig TEXT NOT NULL,
		tags TEXT NOT NULL,
		received_at INTEGER NOT NULL
	);
	CREATE INDEX IF NOT EXISTS idx_events_kind ON events (kind);
	CREATE INDEX IF NOT EXISTS idx_events_pubkey ON events (pubkey);`)
	if err != nil {
		return nil, err
	}
	return &Store{db: db}, nil
}

func (s *Store) Close() error { return s.db.Close() }

// Save inserts an event, returning false if the id already exists (duplicate).
func (s *Store) Save(e *Event) (bool, error) {
	tags, err := jsonMarshal(e.Tags)
	if err != nil {
		return false, err
	}
	res, err := s.db.Exec(`INSERT INTO events (id, pubkey, kind, created_at, content, sig, tags, received_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		e.ID, e.PubKey, e.Kind, e.CreatedAt, e.Content, e.Sig, string(tags), time.Now().Unix())
	if err != nil {
		if isUniqueViolation(err) {
			return false, nil
		}
		return false, err
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}

// Query returns events matching the given NIP-01 filter.
func (s *Store) Query(f Filter) ([]Event, error) {
	where := []string{}
	args := []any{}
	if len(f.IDs) > 0 {
		where = append(where, inClause("id", len(f.IDs)))
		args = append(args, anySlice(f.IDs)...)
	}
	if len(f.Kinds) > 0 {
		where = append(where, inClause("kind", len(f.Kinds)))
		args = append(args, anySlice(f.Kinds)...)
	}
	if len(f.Authors) > 0 {
		where = append(where, inClause("pubkey", len(f.Authors)))
		args = append(args, anySlice(f.Authors)...)
	}
	if f.Since > 0 {
		where = append(where, "created_at >= ?")
		args = append(args, f.Since)
	}
	if f.Until > 0 {
		where = append(where, "created_at <= ?")
		args = append(args, f.Until)
	}
	if len(f.Tags) > 0 {
		// Simple tag matching: filter is {"#e": [...], "#p": [...]}; we
		// match against the serialized tags JSON with a LIKE on the first
		// element of matching tag arrays. Good enough for FarmChore kinds.
		for tag, values := range f.Tags {
			for _, v := range values {
				where = append(where, `tags LIKE ?`)
				args = append(args, `%"`+tag+`","`+v+`%`)
			}
		}
	}
	sqlq := "SELECT id, pubkey, kind, created_at, content, sig, tags FROM events"
	if len(where) > 0 {
		sqlq += " WHERE " + join(where, " AND ")
	}
	sqlq += " ORDER BY created_at ASC"
	if f.Limit > 0 {
		sqlq += " LIMIT ?"
		args = append(args, f.Limit)
	}
	rows, err := s.db.Query(sqlq, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Event{}
	for rows.Next() {
		var e Event
		var tags string
		if err := rows.Scan(&e.ID, &e.PubKey, &e.Kind, &e.CreatedAt, &e.Content, &e.Sig, &tags); err != nil {
			return nil, err
		}
		if err := jsonUnmarshal([]byte(tags), &e.Tags); err != nil {
			log.Printf("bad tags for %s: %v", e.ID, err)
			continue
		}
		out = append(out, e)
	}
	return out, rows.Err()
}
