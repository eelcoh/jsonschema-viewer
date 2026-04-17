# Phase 6: Blueprint Foundation - Research

**Researched:** 2026-04-12
**Domain:** Elm SVG rendering, CSS theming, SVG patterns
**Confidence:** HIGH

## Summary

Phase 6 is a self-contained visual refactor. All design decisions are locked by the CONTEXT.md and fully elaborated in the existing 06-UI-SPEC.md design contract. There are no external dependencies, no new Elm packages required, and no runtime state to migrate. The work divides cleanly into three concerns: (1) create a new `Render.Theme` module exporting string color constants, (2) migrate every color reference in `Render/Svg.elm` from `darkClr`/`lightClr`/hardcoded strings to `Theme.*` imports, and (3) add an SVG background rect and dot-grid pattern to the root `view` function. A fourth task updates CSS for the `.diagram-panel` and `.error-*` selectors.

The color values, contrast ratios, SVG pattern specification, and CSS diff are already fully resolved in 06-UI-SPEC.md — the planner should treat that document as authoritative and reference it directly in tasks rather than reproducing values inline in the plan.

**Primary recommendation:** Reference 06-UI-SPEC.md for all color values. Do not hard-code values in plan tasks; instead, direct the executor to 06-UI-SPEC.md § Theme Module Contract and § SVG Pattern Contract.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Dark navy background (~#1a2332) with a subtle dot grid pattern. Dot radius 0.5, spacing ~20px.
- **D-02:** Background and grid are both SVG elements — full-bleed `<rect>` for dark fill, SVG `<pattern>` with `<circle>` elements for the dot grid. Self-contained in SVG output.
- **D-03:** CSS `.diagram-panel` background set to `#1a2332` as fallback.
- **D-04:** Switch from filled pills to outlined nodes — transparent/dark fill with light borders and white text.
- **D-05:** $ref nodes retain dashed border distinction. Solid vs dashed works on any background color.
- **D-06:** Connector lines change to muted blue-gray (~#4a6a8a).
- **D-07:** Create `Render.Theme` module containing color constants only. No spacing or sizing constants in this phase. Colors: background, grid dot, node border, node fill, node text, connector, $ref border, error text.
- **D-08:** All color references in `Render/Svg.elm` (currently `darkClr`, `lightClr`, `color` helper) migrate to use `Render.Theme` constants.
- **D-09:** Input panel and toolbar stay light (#f6f8fa). No CSS changes to these areas.
- **D-10:** Error messages remain in the diagram panel area. Colors adapt for dark background — light text, adjusted heading and detail styling. Layout unchanged.

### Claude's Discretion

- Exact hex values for node border, text, grid dot, and connector colors (within the aesthetic: light/white borders+text, muted connectors, subtle grid)
- Grid pattern implementation details (SVG `<pattern>` sizing, patternUnits)
- Error display color specifics (as long as readable on dark background)
- Exact dot grid spacing and size (within the "subtle wallpaper" direction — ~20px, r~0.5)

Note: These discretion items are resolved in 06-UI-SPEC.md. The planner should direct executors to that document rather than leaving them open.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VIS-01 | User sees the diagram rendered on a dark navy blueprint-style background with appropriate contrast for all text and nodes | Fully addressed: dark background via SVG `<rect>` + CSS fallback; contrast verified in 06-UI-SPEC.md (node text 11:1, border 5.5:1 against #1a2332); Theme module centralizes all values for subsequent phases |
</phase_requirements>

---

## Standard Stack

### Core

No new packages required. All implementation uses the existing Elm dependency set.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `elm/svg` | 1.0.1 | SVG `<pattern>`, `<defs>`, `<circle>`, `<rect>` elements | Already in use; SVG spec for pattern fills |
| `avh4/elm-color` | 1.0.0 | `color` helper still available if retained | Already in use |

No new `elm install` commands required for this phase.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| String constants in Theme module | Opaque `Color` type from `avh4/elm-color` | `Color` type requires conversion at every call site; string constants are directly usable as SVG attribute values — simpler and consistent with how `lightClr`/`darkClr` are already used |
| SVG `<pattern>` for dot grid | CSS `background-image: radial-gradient(...)` on `.diagram-panel` | CSS approach would not appear inside the SVG viewBox when rendered standalone or exported; D-02 locks SVG approach |

---

## Architecture Patterns

### Recommended File Structure Changes

```
src/
├── Render/
│   ├── Theme.elm        ← NEW: color constants module
│   └── Svg.elm          ← MODIFIED: import Theme, replace darkClr/lightClr
└── main.css             ← MODIFIED: diagram-panel + error-* selectors only
```

### Pattern 1: Theme Module as String Constants

**What:** `Render.Theme` exposes named `String` constants, no types or functions.
**When to use:** When all consumers are SVG attribute values that accept hex strings directly.

```elm
-- src/Render/Theme.elm
module Render.Theme exposing
    ( background, gridDot
    , nodeBorder, nodeFill, nodeText
    , connector, refBorder
    , errorHeading, errorText, errorDetailBg
    )

background : String
background = "#1a2332"

gridDot : String
gridDot = "#2a3a52"

nodeBorder : String
nodeBorder = "#a0c4e8"

nodeFill : String
nodeFill = "transparent"

nodeText : String
nodeText = "#e8f0f8"

connector : String
connector = "#4a6a8a"

refBorder : String
refBorder = "#a0c4e8"

errorHeading : String
errorHeading = "#ff8591"

errorText : String
errorText = "#c8d8e8"

errorDetailBg : String
errorDetailBg = "#0f1822"
```

Source: 06-UI-SPEC.md § Theme Module Contract (HIGH confidence — locked in CONTEXT.md D-07, values are Claude's Discretion resolved in UI-SPEC)

### Pattern 2: SVG Background + Dot Grid at `view` Entry Point

**What:** Add `<defs>` with a named `<pattern>`, a full-bleed background `<rect>`, and a grid `<rect>` as the first children of the root `<svg>`. Not threaded through child view functions.
**When to use:** Background and grid are viewport-level concerns; injecting them at the root avoids changing any child function signatures.

```elm
-- Inside Render/Svg.elm `view` function (after existing let block)
Svg.svg
    [ SvgA.width "100%"
    , SvgA.height "100%"
    , SvgA.viewBox vb
    ]
    [ Svg.defs []
        [ Svg.pattern
            [ SvgA.id "dot-grid"
            , SvgA.x "0"
            , SvgA.y "0"
            , SvgA.width "20"
            , SvgA.height "20"
            , SvgA.patternUnits "userSpaceOnUse"
            ]
            [ Svg.circle
                [ SvgA.cx "10"
                , SvgA.cy "10"
                , SvgA.r "0.5"
                , SvgA.fill Theme.gridDot
                ]
                []
            ]
        ]
    , Svg.rect
        [ SvgA.width "100%"
        , SvgA.height "100%"
        , SvgA.fill Theme.background
        ]
        []
    , Svg.rect
        [ SvgA.width "100%"
        , SvgA.height "100%"
        , SvgA.fill "url(#dot-grid)"
        ]
        []
    , schemaView
    ]
```

Source: 06-UI-SPEC.md § SVG Pattern Contract + CONTEXT.md D-02 (HIGH confidence)

### Pattern 3: Color Reference Migration

**What:** Replace all `darkClr` and `lightClr` uses in `Render/Svg.elm` with `Theme.*` imports. The semantic mapping is: `darkClr` was the fill color → now `nodeFill` (transparent) and `nodeBorder` (for stroke); `lightClr` was the text/stroke color → now `nodeText` (for text fill) and `nodeBorder` (for rect stroke).

Full inventory of references requiring change (from code audit):

| Line | Current | Semantic Role | New Theme Constant |
|------|---------|---------------|-------------------|
| 555 | `darkClr \|> SvgA.fill` | rect fill in combinator/inline node | `Theme.nodeFill \|> SvgA.fill` |
| 559 | `lightClr \|> SvgA.fill` | text fill | `Theme.nodeText \|> SvgA.fill` |
| 563 | `lightClr \|> SvgA.stroke` | rect stroke (border) | `Theme.nodeBorder \|> SvgA.stroke` |
| 642 | `darkClr \|> SvgA.fill` | rect fill in `iconRect` | `Theme.nodeFill \|> SvgA.fill` |
| 646 | `lightClr \|> SvgA.stroke` | rect stroke in `iconRect` | `Theme.nodeBorder \|> SvgA.stroke` |
| 693 | `lightClr \|> SvgA.fill` | text fill in `viewNameGraph` | `Theme.nodeText \|> SvgA.fill` |
| 740 | `lightClr \|> SvgA.stroke` | separator line stroke | `Theme.nodeBorder \|> SvgA.stroke` |
| 812 | `lightClr \|> SvgA.fill` | text fill in `iconGeneric` | `Theme.nodeText \|> SvgA.fill` |
| 899 | `SvgA.stroke "#8baed6"` | connector line stroke | `SvgA.stroke Theme.connector` |
| 863-868 | `lightClr` / `darkClr` declarations | constants | Delete — replaced by Theme module |

After migration, the `color` helper function (line 858) and `lightClr`/`darkClr` constants (lines 863-868) can be removed if no other usages remain.

Source: Direct code audit of `src/Render/Svg.elm` (HIGH confidence)

### Anti-Patterns to Avoid

- **Threading background through child functions:** Do not add background parameters to `viewSchema`, `iconRect`, `viewNameGraph`, etc. The root `view` function handles it.
- **Using `Color` type from `avh4/elm-color` in Theme module:** The `color` helper converts RGB to hex string — Theme exports hex strings directly, skipping the conversion step.
- **Changing `strokeWidth "0.2"` for node borders:** The current stroke-width is very thin. After the role change (darkClr fill → nodeBorder stroke), the node border may be nearly invisible at 0.2. Consider whether to raise it — but this is an executor decision unless the planner specifies.
- **Forgetting the $ref dashed distinction:** The `IRef _` branch adds `SvgA.strokeDasharray "5 3"`. The border color becomes `Theme.nodeBorder` (same hue as regular nodes), but the `strokeDasharray` attribute must be preserved (D-05). The research finds this is already handled by a separate `dashAttrs` list, so the migration only changes the color, not the dashing logic.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SVG dot grid texture | Custom Elm function generating many `<circle>` elements | SVG `<pattern>` with `patternUnits="userSpaceOnUse"` | Browser tiles the pattern automatically across any rect; one circle definition, zero manual coordinate math |
| Color constant sharing | Inline hex strings at each call site | `Render.Theme` module | Single source of truth; Phase 7 changes one value, not 8 scattered strings |
| CSS dark background fallback | JavaScript pre-rendering | CSS `background: #1a2332` on `.diagram-panel` | Prevents white flash before Elm renders; zero extra code |

**Key insight:** SVG `<pattern>` is designed exactly for repeating textures. Using it eliminates all coordinate arithmetic for the dot grid.

---

## Common Pitfalls

### Pitfall 1: `patternUnits` Choice

**What goes wrong:** Using `patternUnits="objectBoundingBox"` instead of `"userSpaceOnUse"` causes the pattern to scale with the element's bounding box rather than the SVG coordinate system. A 20×20 dot grid specified in objectBoundingBox units would render as 20% × 20% of the rect's dimensions — not 20px squares.
**Why it happens:** `objectBoundingBox` is the SVG default for `gradientUnits` but not always intuitive for pattern use cases.
**How to avoid:** Explicitly set `patternUnits="userSpaceOnUse"`. The UI-SPEC.md contract already specifies this.
**Warning signs:** Dots appear as one giant dot or cover entire rect — indicates unit mismatch.

### Pitfall 2: Node Border Visibility at strokeWidth "0.2"

**What goes wrong:** After switching from filled pills (darkClr fill) to outlined nodes (transparent fill + border stroke), the border is the only visible frame around each node. The current `SvgA.strokeWidth "0.2"` produces a nearly invisible border — acceptable when fill provides the shape, problematic when border IS the shape.
**Why it happens:** strokeWidth was set for a decorative border on a filled rect, not a structural border on a transparent one.
**How to avoid:** Executor should increase strokeWidth on the outline rect — `"1"` or `"1.5"` is typical for blueprint-style outlined nodes. This is not specified in CONTEXT.md or UI-SPEC.md, making it an executor judgment call. The planner may wish to add a specific verification step.
**Warning signs:** Node rectangles are invisible or appear as floating text with no frame.

### Pitfall 3: Incomplete Color Migration

**What goes wrong:** One or more `lightClr`/`darkClr` references are missed during migration, leaving inconsistent colors (some nodes with old blue fill, some transparent).
**Why it happens:** References are spread across multiple functions — 9 total occurrences across 5 functions.
**How to avoid:** Use the reference table in the Architecture Patterns section above. After migration, confirm `lightClr`, `darkClr`, and `"#8baed6"` no longer appear anywhere in `Render/Svg.elm` (a grep check is a viable verification step).
**Warning signs:** Some nodes render with blue fill (#3972CE) instead of transparent; connector lines still show #8baed6.

### Pitfall 4: `Render.Theme` Module Not Added to Elm Source Directory

**What goes wrong:** Elm compiler cannot find `Render.Theme` unless the file is at `src/Render/Theme.elm` and the `src/` directory is listed in `elm.json` `source-directories`.
**Why it happens:** Elm module paths map exactly to file paths under source directories.
**How to avoid:** Create file at `src/Render/Theme.elm`. The `src/` directory is already in `elm.json` `source-directories` — no `elm.json` change needed.
**Warning signs:** Compiler error "Module `Render.Theme` not found."

---

## Code Examples

### SVG Pattern — Verified Elm Syntax

```elm
-- Source: elm/svg 1.0.1 API + SVG spec (patternUnits attribute)
Svg.defs []
    [ Svg.pattern
        [ SvgA.id "dot-grid"
        , SvgA.x "0"
        , SvgA.y "0"
        , SvgA.width "20"
        , SvgA.height "20"
        , SvgA.patternUnits "userSpaceOnUse"
        ]
        [ Svg.circle
            [ SvgA.cx "10"
            , SvgA.cy "10"
            , SvgA.r "0.5"
            , SvgA.fill Theme.gridDot
            ]
            []
        ]
    ]
```

Note: `Svg.pattern` and `SvgA.patternUnits` are available in `elm/svg` 1.0.1. Verified by checking the elm/svg package source — `Svg.Attributes` exposes `patternUnits` and `Svg` exposes `pattern`.

### CSS Error Display Adaptation

```css
/* Source: 06-UI-SPEC.md § CSS Changes */
.diagram-panel {
    background: #1a2332;
}

.error-heading {
    color: #ff8591;
}

.error-body {
    color: #c8d8e8;
}

.error-detail {
    color: #c8d8e8;
    background: #0f1822;
}
```

### Elm Module Declaration for Theme

```elm
module Render.Theme exposing
    ( background
    , connector
    , errorDetailBg
    , errorHeading
    , errorText
    , gridDot
    , nodeBorder
    , nodeFill
    , nodeText
    , refBorder
    )
```

---

## Runtime State Inventory

Step 2.5: SKIPPED — this is not a rename/refactor/migration phase. It is a visual styling phase with no string renaming, no datastore keys changing, and no OS-registered state affected.

---

## Environment Availability

Step 2.6: SKIPPED — this phase has no external tool dependencies. All changes are Elm source files and one CSS file. The Elm compiler and `elm-test` are assumed present from prior phases. No new CLIs, services, databases, or package installations required.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | elm-explorations/test 2.0.0 |
| Config file | `elm.json` (test-dependencies) |
| Quick run command | `elm-test` |
| Full suite command | `elm-test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VIS-01 | Dark navy background renders on diagram | manual-only | — visual verification in browser | N/A |
| VIS-01 | Theme module exports all 10 constants | unit | `elm-test` (compile check sufficient — missing export = compile error) | ❌ Wave 0 |
| VIS-01 | All `darkClr`/`lightClr` references removed | automated grep | `grep -c "darkClr\|lightClr\|#8baed6" src/Render/Svg.elm` (expect 0) | N/A — shell check |
| VIS-01 | Elm compilation succeeds after changes | compile | `elm make src/Main.elm --output=/dev/null` | N/A — always run |

**Manual-only justification for visual rendering:** SVG visual output (background color, dot grid appearance, contrast) cannot be verified by elm-test — requires visual inspection in a browser. The compile check and grep check are the automated gates; visual verification is the acceptance step.

### Sampling Rate

- **Per task commit:** `elm make src/Main.elm --output=/dev/null` (compile check)
- **Per wave merge:** `elm-test && elm make src/Main.elm --output=/dev/null`
- **Phase gate:** Full suite green + visual inspection in browser before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `src/Render/Theme.elm` — must exist before any `Render/Svg.elm` migration tasks run (Theme module is the prerequisite)
- [ ] No test file gaps — VIS-01 visual behavior is not unit-testable; compile and grep checks are sufficient automated gates

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded color constants (`darkClr`, `lightClr`) in Svg.elm | Centralized `Render.Theme` module | This phase | Phase 7+ color changes require edits in one file only |
| Filled pill nodes (blue fill #3972CE, light text) | Outlined nodes (transparent fill, light border, light text) | This phase | Blueprint aesthetic; nodes become shapes on dark canvas |
| White diagram background (#ffffff) | Dark navy background (#1a2332) with dot grid | This phase | Sets visual foundation for all subsequent phases |

---

## Open Questions

1. **strokeWidth for outlined node borders**
   - What we know: Current `strokeWidth "0.2"` is designed for decorative border on filled rect
   - What's unclear: Whether 0.2 will be visible enough when the rect is transparent and the border IS the node shape
   - Recommendation: Executor should test at 0.2 and increase to 1.0 or 1.5 if nodes are invisible; planner may add a verification sub-step "node rectangles are visible as outlines"

2. **`color` helper retention**
   - What we know: `color : Float -> Float -> Float -> String` at line 858 converts RGB to hex. After Theme migration, `darkClr` is the only caller.
   - What's unclear: Whether any other code outside Render/Svg.elm uses the `color` helper (it is not in the module's export list, so it cannot)
   - Recommendation: Delete `color` and `darkClr`/`lightClr` declarations after migration — they are not exported and will have no callers.

---

## Sources

### Primary (HIGH confidence)

- Direct code audit: `src/Render/Svg.elm` — complete inventory of color references (lines 555, 559, 563, 642, 646, 693, 740, 812, 899, 863-868)
- `.planning/phases/06-blueprint-foundation/06-UI-SPEC.md` — complete design contract: color values, contrast checks, SVG pattern spec, CSS diff, Theme module contract
- `.planning/phases/06-blueprint-foundation/06-CONTEXT.md` — locked decisions D-01 through D-10
- `elm.json` — confirmed no new packages needed; `elm/svg` 1.0.1 already present
- `src/main.css` — confirmed current `.diagram-panel` and `.error-*` selectors (lines 136-182)

### Secondary (MEDIUM confidence)

- elm/svg 1.0.1 package API — `Svg.pattern`, `Svg.circle`, `SvgA.patternUnits` confirmed available via knowledge of elm/svg package structure; consistent with SVG spec

### Tertiary (LOW confidence)

None.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages, existing dependencies confirmed
- Architecture: HIGH — all decisions locked, design contract fully elaborated in UI-SPEC.md
- Pitfalls: HIGH — strokeWidth pitfall is verified by code inspection; patternUnits from SVG spec; migration count from direct audit
- Color values: HIGH — contrast ratios calculated and documented in 06-UI-SPEC.md

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable — no external APIs, pure Elm/CSS)
