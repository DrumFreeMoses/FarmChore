# FarmChore design: Jacob Springs Farm theme

Source: https://sites.google.com/view/jacobspringsfarm/home and the RAWiki.

## Story

The farm begins each day at dawn with a 15-minute meeting, then chores. Work
is rhythmic, team-based, and rest is honored (Mon–Sat, not Sunday). The design
language is **dawn on the cottonwood row**: amber light over green pastures,
cream milk, and spring water blues.

## Palette

| Token | Hex | Use |
|---|---|---|
| `dawnAmber` | `#E8A33D` | Chores (standard daily work) — filled cards, primary actions |
| `cottonwoodGreen` | `#4E6B3A` | App primary; success, done states |
| `springBlue` | `#5B87A6` | Tasks (one-off work) — outlined cards, accents |
| `milkWhite` | `#FAF6EF` | Backgrounds, cards |
| `soilBrown` | `#5C4A32` | Text, icons |
| `hayYellow` | `#F2D58C` | Pending/attention highlights |
| `sabbath` (rest) | `#8C9A8A` | Sunday/history muted tones |

## Typography

- Display/headers: serif (e.g. Lora) — evokes the print shop heritage
- Body/UI: system sans (e.g. Inter / SF) — readability in sun glare

## Component rules

- **Chore vs Task**: chore = amber filled card + square badge; task = spring
  blue outlined card + rounded badge. Distinguishable at a glance from across
  the milking parlor.
- **Status chips**: done = cottonwood green check; skipped = hay yellow;
  deferred = spring blue arrow; cancelled = soil brown strike.
- **Dashboard**: per-role cards in a grid; a role card shows done/open counts
  for today; tapping drills into that role's list page (e.g. "Milker's Chores").
- **Morning-meeting view**: single column, role-grouped, count of remaining
  work — sized to fit the 15-minute dawn meeting.
- Dark mode: invert to dusk palette (deep soil background, amber accents),
  same tokens.
