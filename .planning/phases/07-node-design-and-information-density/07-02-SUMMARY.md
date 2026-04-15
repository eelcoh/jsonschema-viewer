---
phase: 07-node-design-and-information-density
plan: 02
subsystem: Render.Svg / Main
tags: [hover-overlay, metadata, info-density, mouseenter, HoverState]
dependency_graph:
  requires: ["07-01"]
  provides: [viewHoverOverlay, HoverState, NodeMeta, metaForSchema, hover-event-wiring]
  affects: [src/Main.elm, src/Render/Svg.elm]
tech_stack:
  added: []
  patterns: [ViewConfig record threading, withHoverEvents wrapper, coordinate-based overlay positioning]
key_files:
  created: []
  modified:
    - src/Main.elm
    - src/Render/Svg.elm
decisions:
  - "Thread ViewConfig record through all view functions instead of adding 3 separate hover params to every recursive signature"
  - "Apply withHoverEvents at viewSchema level where path, schema, config, and coords are all available"
  - "Overlay positioned at x=pill_right+8 so it appears to the right without shifting diagram layout"
  - "hasMetadata guard skips hover wiring for nodes with no metadata to avoid spurious events"
metrics:
  duration: ~20 minutes
  completed: "2026-04-15"
  tasks: 1
  files_modified: 2
---

# Phase 7 Plan 02: Hover Overlay System Summary

Implemented full hover overlay system that surfaces schema metadata (description, constraints, enum values) on mouse hover over any diagram node. Nodes without metadata remain unchanged.

## What Was Built

**`NodeMeta` type alias** — captures description, constraints (key-value pairs), enumValues, and baseType extracted from any Schema variant.

**`HoverState` type alias** — carries path, x/y coordinates for overlay positioning, pill width, and NodeMeta. Exposed from module for Main.elm to use.

**`ViewConfig msg` type alias** — bundles toggleMsg, hoverMsg, unhoverMsg into a single record threaded through all recursive view functions. Replaces the individual `(String -> msg)` toggleMsg parameter with a config record to avoid adding 3 more parameters at every recursive call site.

**`metaForSchema : Schema -> Icon -> NodeMeta`** — extracts metadata from each Schema variant. StringSchema extracts description, minLength, maxLength, pattern, enum. IntegerSchema/NumberSchema extract description, minimum, maximum, enum. BooleanSchema extracts description and enum. Object/Array/Null/Ref/combinators extract description only.

**`truncatePattern : String -> String`** — truncates regex patterns longer than 40 chars with ellipsis.

**`hasMetadata : NodeMeta -> Bool`** — returns True if any metadata field is non-empty. Used as guard to skip hover wiring on plain nodes.

**`withHoverEvents`** — wraps a `(Svg msg, Dimensions)` pill in a `Svg.g` with `mouseenter`/`mouseleave` events. Only applied when `hasMetadata` is True. Computes HoverState with overlay position at `pill_right + 8` pixels.

**Refactored all recursive view functions** to accept `ViewConfig msg` instead of `(String -> msg)` toggle: `viewSchema`, `viewProperty`, `viewArrayItem`, `viewProperties`, `viewItems`, `viewAnonymousSchema`, `viewMulti`, `withCombinator`.

**`viewHoverOverlay : Maybe HoverState -> Svg msg`** — renders a dark rounded rect with key/value text rows. Positioned at `hoverState.x, hoverState.y`. Rendered as last child of the root `Svg.svg` to appear on top of all other nodes.

**`buildOverlayRows`** — converts NodeMeta to a list of OverlayRow (key, value strings). Includes type, description (wrapped at 42 chars), enum values (first 5 shown), and constraints.

**`wrapText : Int -> String -> List String`** — simple character-based text wrapping for description lines.

**`renderOverlayRow`** — renders one key (in overlayKeyText color) + value (in nodeText color bold) pair as two SVG text elements.

**Main.elm changes:**
- `hoveredNode : Maybe HoverState` added to Model
- `HoverNode HoverState` and `UnhoverNode` added to Msg
- Update handles `HoverNode` → `hoveredNode = Just hoverState` and `UnhoverNode` → `hoveredNode = Nothing`
- `hoveredNode = Nothing` reset in TextareaChanged, FileContentLoaded, ExampleSelected branches
- `viewDiagramPanel` calls `Render.view ToggleNode HoverNode UnhoverNode model.hoveredNode model.collapsedNodes spec.definitions spec.schema`

## Verification

- `elm-test`: 46 tests pass, 0 failed
- `elm make src/Main.elm --output=/dev/null`: 0 errors

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written with one minor implementation detail:

The `metaForSchema` for `Schema.String` in the plan showed `{ description, minLength, maxLength, pattern, enum }` but the plan text body initially omitted `enum` from the pattern. Added it to correctly extract string enum values, consistent with the Integer/Number/Boolean handling.

## Known Stubs

None. The hover overlay is fully wired end-to-end: pill nodes with metadata fire `HoverNode` on mouseenter, Main.elm stores the state, `Render.view` receives `hoveredNode` and passes it to `viewHoverOverlay` which renders the overlay panel as the last SVG child.

## Self-Check: PASSED

- `src/Main.elm` contains `hoveredNode : Maybe HoverState`
- `src/Main.elm` Msg contains `HoverNode HoverState` and `UnhoverNode`
- `src/Main.elm` update handles both hover messages
- `src/Main.elm` viewDiagramPanel calls `Render.view ToggleNode HoverNode UnhoverNode model.hoveredNode`
- `src/Render/Svg.elm` contains `type alias NodeMeta`
- `src/Render/Svg.elm` contains `type alias HoverState`
- `src/Render/Svg.elm` view signature includes `(HoverState -> msg) -> msg -> Maybe HoverState`
- `src/Render/Svg.elm` contains `viewHoverOverlay`
- `src/Render/Svg.elm` contains `metaForSchema`
- `src/Render/Svg.elm` contains `on "mouseenter"` and `on "mouseleave"`
- `src/Render/Svg.elm` overlay rendered as last child of SVG
- `src/Render/Svg.elm` uses `Theme.overlayBg` and `Theme.overlayKeyText`
- Commit 1f72425 exists in git log
- elm-test: 46 passed, 0 failed
- elm make: Success
