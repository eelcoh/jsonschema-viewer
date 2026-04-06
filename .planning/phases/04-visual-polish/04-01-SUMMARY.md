---
phase: "04-visual-polish"
plan: "01"
subsystem: "Render.Svg"
tags: ["svg", "connector-lines", "bezier", "dashed-border", "elm"]
dependency_graph:
  requires: []
  provides: ["connector lines between parent-child nodes", "dashed border on $ref and cycle pills"]
  affects: ["src/Render/Svg.elm", "tests/Tests.elm"]
tech_stack:
  added: []
  patterns: ["cubic bezier connector path", "conditional SVG attribute pattern"]
key_files:
  created: []
  modified:
    - "src/Render/Svg.elm"
    - "tests/Tests.elm"
decisions:
  - "connectorPathD exposed from module for testability; connectorPath is the SVG emitter"
  - "dashAttrs pattern used to conditionally apply strokeDasharray to IRef _ icon rects"
  - "viewProperties and viewItems take parentRightX parentY before coords for connector origin"
metrics:
  duration: "~110 seconds"
  completed: "2026-04-06"
  tasks_completed: 2
  files_modified: 2
---

# Phase 4 Plan 01: Visual Polish — Connector Lines and Dashed $ref Borders Summary

## One-liner

Cubic bezier connector lines (#8baed6, 1.5px) between all parent-child SVG nodes, and strokeDasharray "5 3" dashed borders on all IRef and cycle pill rects.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Add connectorPathD helper, dashed $ref borders, and unit tests | ee95f90 | src/Render/Svg.elm, tests/Tests.elm |
| 2 | Wire connector lines into viewProperties, viewItems, viewSchema Array/Multi | 70d8ad4 | src/Render/Svg.elm |

## What Was Built

### connectorPathD and connectorPath

Added two functions to `src/Render/Svg.elm`:

- `connectorPathD : Coordinates -> Coordinates -> String` — pure helper that computes the SVG path `d` attribute string for a cubic bezier connector. horizontalOffset = (endX - startX) * 0.5 for control points. Exposed from module for testing.
- `connectorPath : Coordinates -> Coordinates -> Svg msg` — emits an SVG `<path>` with stroke `#8baed6`, strokeWidth `1.5`, strokeLinecap `round`, fill `none`.

### Dashed $ref Borders

In `iconRect`, added `dashAttrs` that pattern-matches on the icon:
- `IRef _ -> [ SvgA.strokeDasharray "5 3" ]`
- `_ -> []`

Applied via list concatenation on the rect attribute list. This covers both expanded/collapsed `$ref` nodes and cycle pills (which use `IRef "*"`).

### Connector Line Wiring

- `viewProperties` signature extended with `parentRightX : Float` and `parentY : Float` before `coords`. Inner `viewProps` loop emits `connectorPath (parentRightX, parentY + 14) (x, y + 14)` for each child (14 = pillHeight / 2).
- `viewItems` signature extended identically. Inner `viewItems_` loop emits the same connector pattern per item.
- `viewSchema` Object branch: passes `w y` as parentRightX/parentY to `viewProperties`.
- `viewSchema` Array branch: emits `itemConnector = connectorPath (w, y + 14) (w + 10, y + 14)` for the single array child.
- `viewMulti`: passes `w y` as parentRightX/parentY to `viewItems`.

Connector lines only appear when nodes are expanded — this is a structural guarantee from the collapsed-check gating in each branch (collapsed nodes skip child rendering entirely).

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All connector lines are wired to live coordinate data.

## Verification

- `elm make src/Main.elm --output=/dev/null` exits 0
- `elm-test` passes 24 tests (7 new connectorPathD/extractRefName/fontWeightForRequired tests + 17 existing)

## Self-Check

- [x] src/Render/Svg.elm modified and committed (ee95f90, 70d8ad4)
- [x] tests/Tests.elm modified and committed (ee95f90)
- [x] connectorPathD exported from module
- [x] elm-test passes
- [x] elm make compiles

## Self-Check: PASSED
