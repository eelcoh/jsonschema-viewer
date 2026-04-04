---
phase: 01-foundation-and-input
plan: 01
subsystem: core
tags: [elm, browser-element, debug-removal, elm-file, foundation]
dependency_graph:
  requires: []
  provides: [Browser.element-entrypoint, elm-file-dependency, debug-free-build]
  affects: [src/Main.elm, src/Render/Svg.elm, src/Json/Schema/Decode.elm, elm.json]
tech_stack:
  added: [elm/file 1.0.5, elm/bytes 1.0.8]
  patterns: [Browser.element with Cmd tuples, expanded Model record, stub update handlers]
key_files:
  created: []
  modified:
    - src/Render/Svg.elm
    - src/Json/Schema/Decode.elm
    - src/Main.elm
    - elm.json
decisions:
  - "Replaced Debug.ToString in constant function with literal 'Constant value mismatch' — type is generic `a` so Json.Encode is not applicable"
  - "Removed swagger test string — it is a Swagger 2.0 spec not a JSON Schema, unsuitable as an example"
  - "Organized jsonschema/jsonschema1/jsonschema3 into exampleContent dispatch function with ExampleArrays/ExamplePerson/ExampleNested variants"
  - "All Msg update handlers are stubs returning (model, Cmd.none) — full logic deferred to Plan 02"
metrics:
  duration_seconds: 121
  completed_date: "2026-04-04"
  tasks_completed: 2
  files_modified: 4
---

# Phase 01 Plan 01: Foundation Cleanup and Browser.element Upgrade Summary

**One-liner:** Removed all Debug.log/Debug.toString calls enabling --optimize builds, and upgraded Browser.sandbox to Browser.element with elm/file dependency and expanded Model/Msg type hierarchy.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Remove all Debug module usage from Render/Svg.elm and Json/Schema/Decode.elm | c392d63 | src/Render/Svg.elm, src/Json/Schema/Decode.elm |
| 2 | Upgrade to Browser.element with expanded Model and install elm/file | 7dd48bd | src/Main.elm, elm.json |

## What Was Built

### Task 1: Debug Removal
Removed three Debug.log call sites from `src/Render/Svg.elm`:
- `Debug.log "schema " schema` in `view` function
- `Debug.log "text color" fg` in `iconGeneric` attributes list
- `Debug.log "red" r` and `|> Debug.log "color"` in the `color` helper function

Removed from `src/Json/Schema/Decode.elm`:
- `import Debug` explicit import
- `Debug.toString` calls in `constant` function — replaced with `fail "Constant value mismatch"`

Result: `elm make src/Main.elm --output=/dev/null --optimize` exits 0.

### Task 2: Browser.element Upgrade
Rewrote `src/Main.elm` from scratch:
- `main` now uses `Browser.element` with `init : () -> (Model, Cmd Msg)` and `update : Msg -> Model -> (Model, Cmd Msg)`
- New `Model` record with 8 fields: `inputText`, `parsedSchema`, `lastValidSchema`, `debounceGeneration`, `displayErrors`, `panelCollapsed`, `selectedExample`, `dragHover`
- New `ExampleSchema` type with `ExampleArrays | ExamplePerson | ExampleNested`
- Full `Msg` type with 9 variants covering all user interaction scenarios for Plan 02
- `exampleContent` function dispatching to `exampleArraysJson`, `examplePersonJson`, `exampleNestedJson`
- Removed `swagger` constant, `viewDefinitions`, `viewSchema`, `viewSpec` development helpers
- Installed `elm/file 1.0.5` in elm.json direct dependencies (plus transitive `elm/bytes 1.0.8`)

## Decisions Made

1. **Debug.ToString replacement:** The `constant` function signature is `constant : a -> Decoder a -> Decoder a` with a generic `a` — Json.Encode.encode cannot serialize an arbitrary `a`. Replaced with `fail "Constant value mismatch"` as recommended in RESEARCH.md.

2. **Swagger removal:** The `swagger` constant held a Swagger 2.0 JSON (not a JSON Schema). It cannot be decoded by `Json.Schema.Decode.decoder` and was only used as a dev scratch pad. Removed entirely.

3. **Stub update handlers:** All Msg variants in `update` return `(model, Cmd.none)`. Full debounce, file reading, and example-switching logic is Plan 02's responsibility.

4. **ExampleSchema naming:** `jsonschema` → `ExampleArrays`/`exampleArraysJson`, `jsonschema1` → `ExamplePerson`/`examplePersonJson`, `jsonschema3` → `ExampleNested`/`exampleNestedJson`. Names reflect schema content rather than arbitrary numbering.

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

```
$ elm make src/Main.elm --output=/dev/null --optimize
Compiling ...             Success!

$ grep -c "Debug" src/Render/Svg.elm src/Json/Schema/Decode.elm
src/Render/Svg.elm:0
src/Json/Schema/Decode.elm:0

$ grep "Browser.element" src/Main.elm
    Browser.element

$ grep "elm/file" elm.json
        "elm/file": "1.0.5",
```

## Known Stubs

The following update handlers are intentional stubs — full implementation is in Plan 02:
- `TextareaChanged _` — debounce logic in Plan 02
- `DebounceTimeout _` — debounce resolution in Plan 02
- `FileDrop _` — file reading pipeline in Plan 02
- `FileContentLoaded _` — schema loading in Plan 02
- `ExampleSelected _` — example switching in Plan 02
- `TogglePanel` — panel collapse in Plan 02
- `DragEnter` / `DragLeave` — drag-over state in Plan 02

These stubs do NOT prevent the plan's goal (clean Browser.element foundation) from being achieved. Plan 02 will wire all handlers.

## Self-Check: PASSED

Files exist:
- FOUND: src/Render/Svg.elm
- FOUND: src/Json/Schema/Decode.elm
- FOUND: src/Main.elm
- FOUND: elm.json

Commits exist:
- c392d63: fix(01-01): remove all Debug module usage
- 7dd48bd: feat(01-01): upgrade to Browser.element with expanded Model and install elm/file
