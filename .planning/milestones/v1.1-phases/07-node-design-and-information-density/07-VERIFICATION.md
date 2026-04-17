---
phase: 07-node-design-and-information-density
verified: 2026-04-15T12:00:00Z
status: passed
score: 5/5 must-haves verified
---

# Phase 7: Node Design and Information Density — Verification Report

**Phase Goal:** Users can distinguish required from optional properties at a glance and read schema metadata (descriptions, constraints, formats, enums) directly on diagram nodes
**Verified:** 2026-04-15
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can see a clear amber border on required property nodes, distinct from optional | VERIFIED | `borderColorForRequired True` returns `"#e8a020"` (amber); `borderColorForRequired False` returns `"#a0c4e8"` (default). Wired through `viewProperty` → `viewSchema` → `iconRect` → `borderColorForRequired isRequired`. 2 unit tests confirm. |
| 2 | User can see string format annotations (email, date-time, uri, etc.) displayed as a compact badge on string nodes | VERIFIED | `iconForSchema` dispatches `IEmail` → "@", `IDateTime` → "dt", `IUri` → "url", etc. All 6 built-in formats plus `ICustom` covered. 7 unit tests confirm format dispatch. `iconGraph` renders each variant via `iconGeneric`. |
| 3 | User can read a node's description as secondary text when the schema has a `description` field | VERIFIED | `metaForSchema` extracts `description` from all Schema variants. `withHoverEvents` fires on mouseenter, stores `HoverState` in `Main.elm` model. `buildOverlayRows` emits `("desc", d)` row. `viewHoverOverlay` renders fixed-position HTML div showing the row. Tested in built-in examples (veggieName, firstName, age). |
| 4 | User can see numeric and length constraints (min/max value, min/max length, pattern) displayed in compact notation on nodes | VERIFIED | `metaForSchema` extracts `minLength`/`maxLength`/`pattern` for strings, `minimum`/`maximum` for integers/numbers. `buildOverlayRows` emits each as a `(key, value)` constraint row. Full data path: decode → model → metaForSchema → HoverState.meta.constraints → viewHoverOverlay row. |
| 5 | User can see enum values displayed on nodes that define an `enum` field | VERIFIED | Dual mechanism: (1) `iconForSchema` returns `IEnum` for any schema variant with a non-Nothing enum — the pill shows "Enum" icon. (2) `metaForSchema` extracts enum values to `NodeMeta.enumValues`; `buildOverlayRows` emits `("enum", "\"val1\", \"val2\", ...")` on hover. Unit test confirms IEnum precedence over format. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/Render/Theme.elm` | `requiredBorder`, `overlayBg`, `overlayBorder`, `overlayKeyText` constants | VERIFIED | All 4 constants present. `requiredBorder = "#e8a020"`, `overlayBg = "#0f1e30"`, `overlayBorder = "#3a5a7a"`, `overlayKeyText = "#8ab0d0"`. Module exposes all 14 constants. |
| `src/Render/Svg.elm` | Extended Icon type, `iconForSchema`, `borderColorForRequired`, `withHoverEvents`, `metaForSchema`, `NodeMeta`, `HoverState` | VERIFIED | All present. `Icon` type has 18 variants including `IEmail`, `IDateTime`, `IHostname`, `IIpv4`, `IIpv6`, `IUri`, `ICustom String`, `IEnum`. All functions substantive. |
| `src/Main.elm` | `hoveredNode` state, `HoverNode`/`UnhoverNode` messages, `viewHoverOverlay`, `buildOverlayRows` | VERIFIED | Model contains `hoveredNode : Maybe HoverState`. Msg has `HoverNode HoverState` and `UnhoverNode`. Update handles both. `viewHoverOverlay` renders fixed-position HTML div with `z-index: 1000`. |
| `tests/Tests.elm` | Unit tests for iconForSchema and borderColorForRequired | VERIFIED | 15 new tests covering all 7 StringFormat variants, enum precedence, integer/number/boolean icon dispatch, and both borderColorForRequired cases. 46 total tests pass. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `src/Render/Svg.elm` (viewProperty) | `src/Render/Svg.elm` (viewSchema) | `isRequired` Bool parameter threading | WIRED | Line 535: `viewSchema ... isRequired property`. `viewProperty` extracts `isRequired` from `Schema.Required`/`Schema.Optional` pattern match at lines 521-527. |
| `src/Render/Svg.elm` (iconRect) | `src/Render/Theme.elm` | `borderColorForRequired isRequired` at line 771 | WIRED | `borderColorForRequired` calls `Theme.requiredBorder` or `Theme.nodeBorder`. Verified in file. |
| `src/Render/Svg.elm` (iconForSchema) | `src/Json/Schema.elm` | `Schema.Email`/`Schema.DateTime` pattern match | WIRED | Lines 658-680: full StringFormat case match present. |
| `src/Render/Svg.elm` (withHoverEvents) | `src/Main.elm` (HoverNode) | `config.hoverMsg` fires with `HoverState` on mouseenter | WIRED | Lines 286-288: `Svg.Events.on "mouseenter" hoverDecoder` decodes `clientX`/`clientY` and fires `config.hoverMsg`. `Main.elm` wires `HoverNode` as `hoverMsg`. |
| `src/Main.elm` (viewDiagramPanel) | `src/Render/Svg.elm` (view) | `Render.view ToggleNode HoverNode UnhoverNode ...` | WIRED | Lines 314, 323: both Ok and lastValidSchema branches call `Render.view` with all hover params. |
| `src/Main.elm` (viewHoverOverlay) | `NodeMeta` via `HoverState` | `buildOverlayRows meta` produces description/constraint/enum rows | WIRED | `viewDiagramPanel` calls `viewHoverOverlay model.hoveredNode` at line 327. `buildOverlayRows` at line 379 processes all NodeMeta fields. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `viewHoverOverlay` (Main.elm) | `meta : NodeMeta` | `metaForSchema schema icon` in `withHoverEvents` | Yes — extracts `description`, `minLength`/`maxLength`/`pattern`, `minimum`/`maximum`, `enum` from live decoded schema | FLOWING |
| `iconGraph` (Render.Svg.elm) | `icon : Icon` | `iconForSchema schema` in each `viewSchema` branch | Yes — dispatches from actual schema variant at render time | FLOWING |
| `borderColorForRequired` | `isRequired : Bool` | `viewProperty` pattern-matching `Schema.Required`/`Schema.Optional` | Yes — reads actual ObjectProperty discriminant from decoded model | FLOWING |

**Note on architectural deviation:** The overlay was originally designed as an SVG element inside `Render.Svg`. During human verification it was found the SVG overlay rendered outside the viewBox. The implementation pivoted to a fixed-position HTML `div` in `Main.elm`. As a result:
- `Render.Svg.view` does not accept `Maybe HoverState` (it was removed)
- `viewHoverOverlay` lives in `Main.elm`, not `Render.Svg.elm`
- The overlay uses hardcoded color literals matching `Theme.overlayBg`/`Theme.overlayBorder`/`Theme.overlayKeyText` values rather than referencing the constants by name

This is a clean architectural decision. The colors are correct and `Main.elm` does not import `Render.Theme`. The theme constants exist but are not consumed for the overlay. This is a minor coupling gap (not a functional gap) — the overlay would survive a Theme color change only if `Main.elm` is also updated manually.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All 46 unit tests pass | `elm-test` | 46 passed, 0 failed, 155ms | PASS |
| App compiles without errors | `elm make src/Main.elm --output=/dev/null` | Success | PASS |
| `borderColorForRequired True` returns amber | Unit test in Tests.elm | Expect.equal "#e8a020" passes | PASS |
| `iconForSchema` String+Email returns IEmail | Unit test in Tests.elm | Expect.equal IEmail passes | PASS |
| `iconForSchema` String+enum returns IEnum over format | Unit test in Tests.elm | Expect.equal IEnum passes | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| NODE-01 | 07-01 | Required vs optional visual marker (border color) | SATISFIED | Amber (`#e8a020`) border on required nodes via `borderColorForRequired`; unit tests verify both states |
| NODE-02 | 07-01 | String format annotations as badges/icons | SATISFIED | `iconForSchema` dispatches all 7 format variants; `iconGraph` renders them via `iconGeneric` |
| INFO-01 | 07-02 | Schema descriptions visible on nodes | SATISFIED | `metaForSchema` extracts description; hover overlay renders `("desc", d)` row |
| INFO-02 | 07-02 | Constraints (min/max length, min/max value, pattern) visible | SATISFIED | `metaForSchema` extracts minLength/maxLength/pattern/minimum/maximum; all rendered as constraint rows in overlay |
| INFO-03 | 07-01 + 07-02 | Enum values visible on nodes | SATISFIED | Dual: (1) "Enum" icon via `iconForSchema`/IEnum on pill; (2) enum values list in hover overlay via `metaForSchema.enumValues` |

All 5 requirement IDs (NODE-01, NODE-02, INFO-01, INFO-02, INFO-03) claimed by the phase plans are satisfied. No orphaned requirements in REQUIREMENTS.md for Phase 7.

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `src/Main.elm:350-351,367` | Hardcoded color literals `"#0f1e30"`, `"#3a5a7a"`, `"#8ab0d0"` instead of `Theme.*` references | Warning | Overlay colors would drift from theme if Theme constants change, requiring dual-site update |

No blockers found. The hardcoded colors are values matching the theme constants exactly — a maintainability warning only.

### Human Verification Required

The following cannot be verified programmatically:

#### 1. Required border visual distinctness at a glance

**Test:** Open the app, load the "Arrays" example (veggie object has required properties), compare `veggieName` and `veggieLike` (required) vs root-level properties (optional).
**Expected:** Required property pill borders are visibly warm amber (#e8a020), optional are cooler blue-grey (#a0c4e8). The difference is immediately apparent without relying on font weight.
**Why human:** Color perception and "at a glance" distinctness cannot be asserted by static analysis.

#### 2. Format icon readability on pill nodes

**Test:** Paste `{"type":"object","properties":{"email":{"type":"string","format":"email"},"created":{"type":"string","format":"date-time"},"website":{"type":"string","format":"uri"}}}`.
**Expected:** Pill nodes show "@", "dt", "url" icons respectively — compact and legible.
**Why human:** Icon label legibility within the pill layout requires visual inspection.

#### 3. Hover overlay appears, positions correctly, and disappears

**Test:** Load any example with descriptions (e.g., "Person" example). Hover over `firstName`. Move mouse away.
**Expected:** Dark overlay panel appears adjacent to cursor showing `desc  The person's first name.`. Panel disappears on mouse leave. Overlay is not clipped or off-screen.
**Why human:** Mouse event behavior, overlay positioning relative to viewport edges, and z-index layering require interactive testing.

#### 4. Enum values shown correctly in overlay

**Test:** Load TypeBox example. Hover over the `role` property (which has `enum: ["admin"]` or `enum: ["user"]`).
**Expected:** Pill shows "Enum" icon. Hovering reveals overlay with `enum  "admin"` (or `"user"`).
**Why human:** Interactive hover behavior requires live testing.

### Gaps Summary

No gaps. All 5 success criteria are verified as implemented and wired end-to-end.

The one architectural deviation from Plan 07-02 (overlay rendered as HTML in `Main.elm` instead of SVG in `Render.Svg`) was executed during implementation after discovering the SVG approach failed in the browser. The deviation is documented in the SUMMARY and results in functionally correct behavior. The minor coupling gap (hardcoded theme colors in `Main.elm`) is a warning, not a blocker.

---

_Verified: 2026-04-15_
_Verifier: Claude (gsd-verifier)_
