---
phase: "06"
plan: "01"
subsystem: "Render"
tags: [theme, colors, svg, css, blueprint]
dependency_graph:
  requires: []
  provides: ["Render.Theme module", "blueprint SVG background", "dark CSS panel"]
  affects: ["src/Render/Svg.elm", "src/main.css"]
tech_stack:
  added: []
  patterns: ["centralized color constants module", "SVG pattern element for dot grid"]
key_files:
  created: ["src/Render/Theme.elm"]
  modified: ["src/Render/Svg.elm", "src/main.css"]
decisions:
  - "strokeWidth increased from 0.2 to 1 — outlined nodes require visible border width"
  - "color helper function removed alongside lightClr/darkClr — Theme module replaces all"
  - "public/main.css excluded from git (gitignored as build output) — copied at build time"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-12"
  tasks_completed: 3
  files_changed: 3
---

# Phase 6 Plan 1: Blueprint Foundation — Theme Module and Dark Background Summary

Blueprint visual foundation established: dark navy SVG background (#1a2332) with dot grid texture, outlined pill nodes (transparent fill, #a0c4e8 borders, stroke 1px), muted connector lines (#4a6a8a), and all 10 color constants centralized in a new `Render.Theme` module replacing inline `darkClr`/`lightClr` helpers.

## What Was Built

### Task 1: Render.Theme module (commit b835b85)
Created `src/Render/Theme.elm` — a new Elm module exporting 10 string constants as direct SVG attribute values. No Color type dependency, no computation — pure hex strings. Constants cover the full visual vocabulary: background, grid, node borders/fill/text, connectors, ref borders, and error display colors.

### Task 2: Migrate Render/Svg.elm to Theme colors with dot grid (commit b601e0f)
- Removed `import Color exposing (gray)` and `import Color.Convert` (now unused)
- Added `import Render.Theme as Theme`
- Replaced all 9 occurrences of `lightClr`/`darkClr`/`#8baed6` with Theme references
- Deleted the `color`, `lightClr`, `darkClr` local definitions (14 lines removed)
- Added `<defs>` with dot grid `<pattern>` (20x20 tiles, 0.5px radius circles at Theme.gridDot)
- Added dark navy background `<rect>` and dot grid overlay `<rect>` in `view`
- Increased `strokeWidth` from "0.2" to "1" in both `roundRect` and `iconRect` for visible outlined borders

### Task 3: Update CSS for dark diagram panel (commit dd418b5)
Updated 5 CSS properties in `src/main.css`:
- `.diagram-panel` background: `#ffffff` → `#1a2332` (prevents white flash on load)
- `.error-heading` color: `#cf222e` → `#ff8591` (readable red on dark background)
- `.error-body` color: `#293c4b` → `#c8d8e8` (cool light-gray)
- `.error-detail` color: `#293c4b` → `#c8d8e8`
- `.error-detail` background: `#f6f8fa` → `#0f1822` (slightly darker than canvas)
- Input panel and toolbar CSS untouched (D-09)

## Decisions Made

1. **strokeWidth 0.2 → 1**: Outlined nodes (transparent fill) require a visible border; 0.2px is nearly invisible against dark navy. This is a correctness requirement, not a preference.
2. **color helper removed**: The `color r g b = Color.rgb r g b |> Color.Convert.colorToHex` helper and its two consumers (`lightClr`, `darkClr`) are all replaced by Theme. Keeping the helper would require retaining two unused elm-color packages.
3. **public/main.css not committed**: `.gitignore` excludes `public/main.css` as a build artifact. The CSS is copied at build time per CLAUDE.md build instructions.

## Verification Results

- `elm make src/Main.elm --output=/dev/null` — exits 0
- `elm-test` — 31/31 tests pass, 0 regressions
- `grep -c "darkClr\|lightClr\|#8baed6\|import Color" src/Render/Svg.elm` — returns 0
- `grep -c "^[a-z].*: String$" src/Render/Theme.elm` — returns 10

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all color constants are wired to live SVG rendering code.

## Self-Check: PASSED

- `src/Render/Theme.elm` exists: FOUND
- `src/Render/Svg.elm` contains `import Render.Theme as Theme`: FOUND
- Commits b835b85, b601e0f, dd418b5 exist in git log: FOUND
- 31 tests pass: CONFIRMED
