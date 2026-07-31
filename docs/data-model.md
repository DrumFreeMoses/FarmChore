# FarmChore data model

All domain data is signed Nostr events (NIP-01). The farm namespace is rooted
at the farm pubkey: clients only sync events whose `p`/`farm` tag or author
matches the farm.

## Event kinds

| Kind | Name | Semantics |
|------|------|-----------|
| `31500` | Role default set | Per-role daily chore defaults (addressable by role or `role:variant`) |
| `31501` | Chore/Task instance | A scheduled item for a date |
| `31502` | Assignment | Assign/self-assign an instance to a member |
| `31503` | Edit | Revision of an instance or default (one-time vs default) |
| `31504` | Member profile | A member's display name (addressable by pubkey) |
| `31505` | Heads-up | Farm notice for the whole farm or one role group |

Kinds are in the addressable range (30000-39999), so relays keep only the
latest event per `(kind, pubkey, d-tag)`.

## Role default set (31500)

Addressable event, `d` tag = role name.

Roles: `Milkers`, `Pourers`, `Feeders`, `Mechanics`, `Farmers`, `Non-JSF`.

```json
{
  "kind": 31500,
  "content": "{\"chores\": [{\"title\": \"Morning milking\", \"weekdays\": [1,2,3,4,5,6], \"assigneeHint\": null}]}",
  "tags": [
    ["d", "Milkers"],
    ["farm", "<farm pubkey>"]
  ]
}
```

`weekdays`: 1=Monday .. 6=Saturday (the farm works Mon-Sat; Sundays rest,
per the farm's Sabbath practice).

## Chore/Task instance (31501)

A regular event; `d` tag = `date|role|slug` to make a day's item addressable
and idempotent.

```json
{
  "kind": 31501,
  "content": "{\"title\": \"Morning milking\", \"type\": \"chore\", \"status\": \"open\", \"deferredTo\": null}",
  "tags": [
    ["d", "2026-07-31|Milkers|morning-milking"],
    ["role", "Milkers"],
    ["date", "2026-07-31"],
    ["farm", "<farm pubkey>"],
    ["assignee", null]
  ]
}
```

- `type`: `chore` (standard daily work) or `task` (one-off auxiliary work)
- `status`: `open | done | skipped | deferred | cancelled`
- a deferred instance carries `deferredTo` (ISO date) and is regenerated
  there

## Assignment (31502)

```json
{
  "kind": 31502,
  "content": "",
  "tags": [
    ["e", "<instance event id>"],
    ["p", "<member pubkey>"],
    ["farm", "<farm pubkey>"]
  ]
}
```

Self-assignment is just an assignment whose `p` tag is the signer.

## Edit (31503)

```json
{
  "kind": 31503,
  "content": "{\"field\": \"status\", \"value\": \"done\", \"scope\": \"one-time\"}",
  "tags": [
    ["e", "<instance event id>"],
    ["d", "<instance event id>"],
    ["farm", "<farm pubkey>"]
  ]
}
```

- `scope`: `one-time` (this instance only) vs `default` (also updates the
  role default set)
- every edit is signed, so the event log doubles as an audit trail

## Identity

- Members: Nostr keypair generated in-app; identity is the pubkey only.
  No names, emails, or phone numbers (no PII).
- Farm: a pubkey that anchors the namespace; invite = farm pubkey + role,
  shared as QR code.

## Conflict handling

LWW (last-write-wins) per instance/record, by `created_at` then event id
lexicographic order — matching NIP-01 tie-breaking.
