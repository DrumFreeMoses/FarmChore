# FarmChore

Local-first chore management for Jacob Springs Farm (Boulder, CO): standardized daily **chores** vs. one-off **tasks**, organized by farm role, synced in real time over a small Nostr-compatible relay — no PII, no accounts, no cost.

## Negotiated architecture (2026-07-31)

| Decision | Choice | Rationale |
|---|---|---|
| Sync model | Local-first + small relay | Works offline in the field; real-time when connected; mesh (Bitchat-style) possible later |
| App stack | Flutter | One codebase: iOS, Android, web, desktop |
| Data sync | Signed Nostr events (custom kinds) over NIP-01 relay | Noob-friendly Nostr identity; free relay ecosystem; mesh upgrade path |
| Identity | In-app generated nsec, pubkey-only | No PII by construction |
| Notifications | In-app only (v1) | Push (APNs/FCM) deferred to phase 2 |
| Hosting | fly.io relay + Cloudflare Pages web; GitHub Actions CI | ~$0/month free tiers |
| Method | TDD (red-green-refactor), kanban on GitHub Projects | Spec requirement |

## Data model (Nostr event kinds)

| Kind | Name | Content |
|---|---|---|
| `31500` | Role default set | Per-role daily chore defaults (Milkers, Pourers, Feeders, Mechanics, Farmers, Non-JSF) |
| `31501` | Chore/Task instance | A scheduled item for a date: title, role, date, status (open / done / skipped / deferred / cancelled) |
| `31502` | Assignment | Assign or self-assign an instance to a member pubkey |
| `31503` | Edit | Revision to a default or instance (one-time vs. default edits) |

The farm namespace is rooted at the farm pubkey; members join by receiving the farm pubkey + role. Event log (NIP-01 `EVENT`) doubles as the audit trail.

## Repository layout

```
app/            Flutter client (iOS, Android, web, desktop)
relay/          Minimal NIP-01 relay (Go, SQLite persistence)
docs/           Architecture, design, deployment, budget
.github/workflows/  CI (analyze, format, test, build)
```

## Roadmap

Full backlog lives on the [FarmChore GitHub Projects board](https://github.com/DrumFreeMoses/FarmChore/projects).
