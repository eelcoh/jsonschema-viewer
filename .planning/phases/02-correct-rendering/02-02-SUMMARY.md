---
phase: 02-correct-rendering
plan: 02
subsystem: rendering
tags: [elm, svg, ref-rendering, viewbox, font-weight, cycle-detection]
dependency_graph:
  requires: [02-01]
  provides: [REND-01, REND-02, REND-03]
  affects: [src/Render/Svg.elm]
tech_stack:
  added: []
  patterns: [visited-set-threading, dynamic-viewbox, font-weight-distinction]
key_files:
  created: []
  modified: [src/Render/Svg.elm]
decisions:
  - Thread visited Set String through all view functions to enable cycle detection without architectural change
  - IRef icon shows just '*' (not '*' ++ name) — definition name goes in the name section via iconRect label
  - Recursive child calls always pass '700' weight to prevent weight from propagating to nested schemas
metrics:
  duration: "~10 minutes"
  completed: "2026-04-05"
  tasks_completed: 2
  files_modified: 1
---

# Phase 02 Plan 02: Phase 2 Rendering Implementation Summary

**One-liner:** All three Phase 2 rendering changes implemented in src/Render/Svg.elm — $ref nodes show definition name with cycle guard (↺), SVG viewBox dynamically scales from computed dimensions + 20px padding, required properties render bold (700) and optional properties render normal weight (400).

## What Was Built

Applied all three Phase 2 rendering improvements to `src/Render/Svg.elm`:

1. **REND-01: $ref nodes show definition name with cycle detection**
   - `extractRefName` extracts the definition name from the full `#/definitions/` key
   - `isCircularRef` checks if a ref is already in the visited set
   - `refLabel` appends ` ↺` when circular
   - Removed old `Dict.get ref defs` + `roundRect ref` secondary rendering (no inline expansion per D-02)
   - IRef icon changed from `"*" ++ s` to just `s` (now passing `"*"` as the icon string)

2. **REND-02: Dynamic viewBox**
   - `view` now captures `( schemaView, ( w, h ) )` from `viewSchema`
   - `viewBoxString w h 20` computes `"0 0 {w+20} {h+20}"`
   - SVG `width` and `height` changed from `"520"` to `"100%"` (D-09)

3. **REND-03: Required/optional font weight distinction**
   - `weight : String` parameter added to `viewSchema`, `iconRect`, `viewNameGraph`, `viewString`, `viewInteger`, `viewFloat`, `viewBool`
   - `viewProperty` extracts `isRequired` from `Schema.Required`/`Schema.Optional` and calls `fontWeightForRequired`
   - `viewNameGraph` now uses `SvgA.fontWeight weight` instead of hardcoded `"700"`
   - All recursive child calls pass `"700"` to prevent weight propagating to nested schemas (RESEARCH.md Pitfall 5)

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Thread visited set and implement $ref rendering | 7a2e37f | src/Render/Svg.elm |
| 2 | Implement dynamic viewBox and font weight distinction | 7a2e37f | src/Render/Svg.elm |
| 3 | Visual verification | 87d531d | src/Render/Svg.elm |

Note: Tasks 1 and 2 were implemented in a single pass and committed together since the changes were tightly coupled (weight parameter threading touches the same call sites as visited set threading). Task 3 verification revealed a layout overlap bug, fixed in commit 87d531d.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Object/Array min-height layout constraint**
- **Found during:** Task 3 (visual verification with medium-sized-schema.json)
- **Issue:** Object schemas decoded with empty properties (e.g., `type: "object"` + `$ref` without `properties` key) returned input y unchanged, causing sibling properties to overlap vertically
- **Fix:** Added `Basics.max h ph` in Object and Array branches so returned dimensions always include at least the node's own pill height (28px)
- **Files modified:** src/Render/Svg.elm
- **Verification:** medium-sized-schema.json renders without overlap, elm-test passes 15/15
- **Committed in:** 87d531d

### Decisions Made

- **Thread visited Set String through all view functions**: Implemented exactly as specified — `Set.empty` at entry point (`view`), `visited` unchanged at all recursive calls.
- **IRef icon shows just `s` (not `"*" ++ s`)**: Changed `IRef s -> iconGeneric coords ("*" ++ s)` to `IRef s -> iconGeneric coords s`. Since the Ref branch now passes `IRef "*"`, the icon area shows `"*"` and the definition name goes in the name section via the `txt` parameter of `iconRect`.
- **Recursive child calls pass `"700"`**: Weight does not propagate from parent to children — each nested schema uses default bold weight unless `viewProperty` explicitly sets it.
- **Min-height constraint**: Object and Array nodes now return `Basics.max h ph` to ensure at least pill height in dimensions, preventing overlap with real-world schemas that have type+$ref without properties.

## Verification Results

- `elm make src/Main.elm --output=/dev/null` — Success: 4 modules compiled
- `elm make src/Main.elm --output=public/elm.js --optimize` — Success
- `elm-test` — PASSED: 15 tests, 0 failures

## Known Stubs

None — all rendering changes are fully wired. No placeholder values or hardcoded mock data.

## Self-Check: PASSED

- src/Render/Svg.elm contains `viewSchema : Set String -> Definitions -> Coordinates -> Maybe Name -> String -> Schema`
- src/Render/Svg.elm contains `viewSchema Set.empty defs` in `view`
- src/Render/Svg.elm contains `extractRefName ref`, `isCircularRef visited ref`, `refLabel defName isCycle` in Ref branch
- src/Render/Svg.elm does NOT contain `roundRect ref`
- src/Render/Svg.elm contains `SvgA.width "100%"`, `SvgA.height "100%"`, `viewBoxString w h 20`
- src/Render/Svg.elm does NOT contain `"520"` in the view function
- src/Render/Svg.elm contains `viewNameGraph : String -> Coordinates` with `SvgA.fontWeight weight`
- src/Render/Svg.elm contains `fontWeightForRequired isRequired` in `viewProperty`
- src/Render/Svg.elm contains `Basics.max h ph` in Object branch (min-height fix)
- src/Render/Svg.elm contains `Basics.max h ih` in Array branch (min-height fix)
- Commits 7a2e37f and 87d531d exist in git log
- 15/15 elm-test tests pass
- Visual verification approved by user after min-height fix
