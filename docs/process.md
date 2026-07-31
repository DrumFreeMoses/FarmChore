# Process: TDD, sprints, definition of done

## TDD (red-green-refactor)

1. Write a failing test for the behavior (red).
2. Implement the minimum to pass (green).
3. Refactor without changing behavior.

Tests run in CI on every push/PR: `flutter analyze`, `dart format`,
`flutter test` for the app; `go vet`, `go test` for the relay.

## Sprint cadence

- Sprints are one week, aligned to the farm's Mon–Sat rhythm; review happens
  Saturday morning.
- Backlog grooming: move items between sprints via `tools/board.py`.
- WIP limit: 5 items in progress at once; finish before starting.

## Definition of done

An issue is Done only when all of:

- [ ] Feature code has a failing test first (or the change is docs-only)
- [ ] CI passes (analyze + format + tests for the app; vet + tests for the relay)
- [ ] User-facing behavior verified on at least one platform (web or device)
- [ ] Relevant docs updated (`docs/`)
- [ ] Board status moved to Done with a release note in the issue
