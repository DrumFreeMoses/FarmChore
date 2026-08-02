# FarmChore admin guide

For the farm owner/operator who manages the system.

## Getting started

1. **Open the app** — your identity is created automatically (a Nostr keypair).
2. **Set your name** — tap the badge icon in the appbar, enter your first name.
3. **Load demo data** — if you see the agriculture icon, tap it to seed example
   chores and role defaults.
4. **Customize defaults** — edit the role defaults to match your farm's actual
   chore schedule. Changes propagate to all connected devices.

## Managing roles

Each role (Milkers, Pourers, Feeders, Mechanics, Farmers, Non-JSF) has a set
of daily chore defaults. These are Nostr events (kind 31500) synced to the
relay.

- **Add a chore**: edit the role's default set and add a new title + weekday
  schedule.
- **Remove a chore**: delete it from the defaults; existing instances stay in
  history.
- **Reorder**: the app sorts chores alphabetically within each role.

## Day off and skills

Each member profile (kind 31504) carries:
- `dayOff`: weekday number (1=Mon, 6=Sat) when the member doesn't work.
- `skills`: list of skill tags (e.g. `milker`, `tractor`).

When generating today's instances, the app:
1. Filters out members whose `dayOff` matches today's weekday.
2. Filters out members who lack the `requiredSkills` for a chore.
3. Falls back to the `assigneeHint` if no member qualifies.

## Inviting workers

1. Tap the **QR icon** in the appbar.
2. Show the QR code to the new worker's phone.
3. They scan it — the app connects to your relay and joins the farm namespace.

The QR encodes: `{"relay": "wss://...", "pubkey": "farm-pubkey", "name": "Farm"}`

## Sync and relay

All data syncs through a NIP-01 relay:
- **Local-first**: the app works offline. Changes queue and push when online.
- **Live updates**: the app maintains a persistent subscription — changes from
  other devices appear instantly.
- **Conflict resolution**: last-write-wins per event (by `created_at` then id).

## Deployment

See `docs/deployment.md` for relay and web hosting setup.

## Event kinds reference

| Kind | Name | Purpose |
|------|------|---------|
| 31500 | RoleDefaultSet | Per-role chore schedule |
| 31501 | ChoreInstance | Daily instance |
| 31502 | Assignment | Who's doing what |
| 31503 | Edit | Status changes, renames |
| 31504 | MemberProfile | Name, day off, skills |
| 31505 | HeadsUp | Farm notices |
| 31506 | FarmMessage | Broadcast + DMs |
