---
phase: 03-expand-collapse
plan: "01"
subsystem: Render.Svg
tags: [elm, svg, expand-collapse, interactive, path-threading]
dependency_graph:
  requires: []
  provides: [expand-collapse-renderer, toggleInSet, path-threaded-view]
  affects: [src/Main.elm]
tech_stack:
  added: [Svg.Events, Json.Decode (for stopPropagationOn decoder)]
  patterns: [clickableGroup wrapper, path-accumulator threading, Set-based collapse state, visited-set cycle guard]
key_files:
  created: []
  modified:
    - src/Render/Svg.elm
    - src/Main.elm
    - tests/RenderHelpers.elm
decisions:
  - toggleInSet exposed from Render.Svg so Main.elm can reuse it without re-implementing
  - clickableGroup wraps stopPropagationOn to prevent event bubbling from nested containers
  - path segment separator is dot (.); property paths use .properties.name, array items .items, combinators indexed
  - Ref branch: cycle pill not clickable, collapsed shows label pill, expanded renders inline with visited-set guard
  - Main.elm collapsedNodes resets to Set.empty on every schema re-parse (D-03)
metrics:
  duration: ~15 minutes
  completed: "2026-04-05"
  tasks_completed: 2
  files_modified: 3
---

# Phase 3 Plan 1: Render.Svg Expand/Collapse Renderer Summary

## One-liner

Interactive SVG renderer with path-threaded collapse state, stopPropagationOn click handlers, and inline $ref expansion using visited-set cycle guard.

## What Was Built

Updated `src/Render/Svg.elm` to support interactive expand/collapse of container nodes. The renderer now accepts a message constructor `(String -> msg)` and a `Set String` of collapsed path keys, threading both through all view functions alongside the existing visited set and coordinates.

### Key Changes

**New `view` signature:**
```elm
view : (String -> msg) -> Set String -> Definitions -> Schema -> Html.Html msg
```

**New `clickableGroup` helper:**
Wraps any `(Svg msg, Dimensions)` in a `<g>` element with `Svg.Events.stopPropagationOn "click"` and `SvgA.cursor "pointer"`. Used on all container pills (Object, Array, OneOf, AnyOf, AllOf, non-cycle Ref).

**Path threading:**
Each view function now accepts `path : String`. Paths accumulate dot-separated: `root.properties.address.properties.street`, `root.items`, `root.oneOf.0`.

**Conditional rendering:**
Container branches check `Set.member path collapsedNodes` — if collapsed, render pill only; if expanded, render pill plus children.

**$ref inline expansion:**
- Cycle: render cycle pill (not clickable, D-05)
- Collapsed: render label pill with click handler
- Expanded + definition found: render definition inline via `viewSchema (Set.insert ref visited) ...`, wrapped with clickableGroup
- Expanded + definition not found: render label pill (not clickable — nothing to expand)

**Leaf nodes** (String, Integer, Number, Boolean, Null): no click handler, no pointer cursor (D-10).

**`toggleInSet` helper** exported from `Render.Svg` and used by `Main.elm` in the `ToggleNode` update case.

### Main.elm Updates

- Added `collapsedNodes : Set String` to `Model` (init: `Set.empty`)
- Added `ToggleNode String` to `Msg`
- Added `ToggleNode` update case calling `Render.toggleInSet`
- Reset `collapsedNodes = Set.empty` in `TextareaChanged`, `FileContentLoaded`, `ExampleSelected` (D-03)
- Updated both `Render.view` call sites to pass `ToggleNode model.collapsedNodes`

### Tests Added

4 new unit tests in `tests/RenderHelpers.elm` for `toggleInSet`:
- inserts key when absent
- removes key when present
- does not affect other keys
- inserts into non-empty set

Total test suite: 19 tests, all passing.

## Deviations from Plan

### Non-plan changes: Main.elm updated as part of Task 2

The plan listed `src/Main.elm` under `files_modified` in the frontmatter but the tasks only explicitly called for changes to `src/Render/Svg.elm` and `tests/RenderHelpers.elm`. Since `Render.Svg.view` signature changed, `Main.elm` required corresponding updates to compile. These were applied as part of Task 2 under Rule 3 (blocking issue — changed API signature would prevent compilation).

Changes to `Main.elm`:
- Added `collapsedNodes`, `ToggleNode`, reset logic, updated call sites
- Files modified: `src/Main.elm`

### Merge from master (pre-task)

The worktree branch was behind master (predating Phase 2). A merge from master was committed before implementing Phase 3 changes to bring in the Phase 2 completed `Render/Svg.elm`, `tests/RenderHelpers.elm`, and all planning files.

## Known Stubs

None — all container branches have functioning click handlers and conditional rendering wired end-to-end.

## Self-Check: PASSED

- src/Render/Svg.elm: FOUND
- src/Main.elm: FOUND
- tests/RenderHelpers.elm: FOUND
- .planning/phases/03-expand-collapse/03-01-SUMMARY.md: FOUND
- Commit cb899b7 (feat(03-01): add toggleInSet helper and unit tests): FOUND
- Commit 8cca95e (feat(03-01): update Render.Svg with expand/collapse support): FOUND
