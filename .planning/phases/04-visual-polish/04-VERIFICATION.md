---
phase: 04-visual-polish
verified: 2026-04-06T10:00:00Z
status: human_needed
score: 5/5 must-haves verified
re_verification: false
human_verification:
  - test: "Connector lines visible between parent and child nodes"
    expected: "Smooth cubic bezier curves connect the root object pill to each of its child property pills"
    why_human: "SVG rendering requires visual inspection in a browser; cannot verify curve appearance programmatically"
  - test: "Connector lines appear and disappear with expand/collapse"
    expected: "Clicking a parent node hides its children and the connector lines; clicking again reveals both"
    why_human: "Interactive DOM state change requires browser testing"
  - test: "$ref node border is visually dashed"
    expected: "Pills for $ref schemas show a dashed border distinct from the solid borders on object/string/array nodes"
    why_human: "Rendered CSS/SVG attribute appearance requires visual browser check; attribute presence verified programmatically but visual effect confirmed by eye"
  - test: "Cycle pill (arrow symbol) also shows dashed border"
    expected: "The cycle indicator pill uses IRef '*' and therefore receives the same strokeDasharray '5 3' dashed border"
    why_human: "Requires a schema with an actual circular $ref to trigger the cycle pill code path in browser"
---

# Phase 4: Visual Polish Verification Report

**Phase Goal:** The diagram communicates tree structure clearly through connector lines between parent and child nodes, and $ref nodes are visually distinguishable from inline schema nodes
**Verified:** 2026-04-06T10:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Connector lines visually link each parent node to its child nodes | ✓ VERIFIED | `connectorPath` called in `viewProperties` (line 92), `viewItems` (line 137), and Array branch `itemConnector` (line 244); wired from parent right-edge to child left-edge |
| 2 | Connector lines appear only when a node is expanded and disappear when collapsed | ✓ VERIFIED | Four `Set.member path collapsedNodes` guards (lines 210, 230, 279, 315) gate child rendering; connector emission is structurally inside the else-branch, so collapsed nodes produce no connectors |
| 3 | $ref nodes have a dashed border distinguishing them from inline schema nodes | ✓ VERIFIED | `dashAttrs` in `iconRect` pattern-matches `IRef _ -> [ SvgA.strokeDasharray "5 3" ]` (lines 560-566); applied via `++ dashAttrs` on rect attribute list |
| 4 | Cycle indicator pills also have a dashed border | ✓ VERIFIED | Cycle pill calls `iconRect (IRef "*") ...` (line 277); `IRef _` pattern matches, so `strokeDasharray "5 3"` is applied |
| 5 | Combinator nodes (oneOf/anyOf/allOf) also show connector lines to sub-schemas | ✓ VERIFIED | `viewMulti` calls `viewItems visited defs collapsedNodes toggleMsg path w y (w + 10, y) schemas` (line 321), passing parent right-edge coords; `viewItems` emits connectors per sub-schema |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/Render/Svg.elm` | `connectorPath` function, dashed border in `iconRect`, connector emission in `viewProperties`/`viewItems` | ✓ VERIFIED | All three deliverables present; file modified in commits ee95f90 and 70d8ad4 |
| `tests/Tests.elm` | Unit tests for `connectorPathD` coordinate math and helper functions | ✓ VERIFIED | 5 new tests for `connectorPathD` (2), `extractRefName` (1), `fontWeightForRequired` (2); all pass |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `viewProperties` inner loop | `connectorPath` | emits SVG path for each child alongside child render | ✓ WIRED | Line 92-94: `connector = connectorPath (parentRightX, parentY + 14) (x, y + 14)` prepended to output list |
| `viewItems` inner loop | `connectorPath` | emits SVG path for each array item/sub-schema | ✓ WIRED | Line 137-139: same pattern as viewProperties |
| `iconRect` | `strokeDasharray` | conditional attribute when icon is `IRef` | ✓ WIRED | Lines 560-566: `dashAttrs` pattern match; line 580: `++ dashAttrs` appended to rect attrs |
| `viewSchema` Object branch | `viewProperties` with `w y` | passes parent right-edge X and Y for connector origin | ✓ WIRED | Line 216: `viewProperties ... path w y (w + 10, y) properties` |
| `viewMulti` | `viewItems` with `w y` | passes combinator pill right-edge for connector origin | ✓ WIRED | Line 321: `viewItems ... path w y (w + 10, y) schemas` |
| `viewSchema` Array branch | `itemConnector` | direct `connectorPath` call for single array child | ✓ WIRED | Lines 243-247: `itemConnector = connectorPath (w, y + 14) (w + 10, y + 14)` included in `graphs` list |

### Data-Flow Trace (Level 4)

Not applicable. `src/Render/Svg.elm` is a pure rendering module — it receives all data via function arguments (`schema`, `defs`, `collapsedNodes`) and transforms to SVG output. There is no internal state or fetch. The coordinate threading pattern passes live coordinate values through recursive calls; no static defaults are used for connector endpoints.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `connectorPathD` produces correct bezier string (horizontal) | `elm-test` | 24 tests passed | ✓ PASS |
| `connectorPathD` produces correct bezier string (diagonal) | `elm-test` | 24 tests passed | ✓ PASS |
| Module compiles without errors | `elm make src/Main.elm --output=/dev/null` | Exit 0 | ✓ PASS |
| `connectorPathD` exported from module | Module header line 1 | `exposing (..., connectorPathD)` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| VIS-01 | 04-01-PLAN.md | Connector lines link parent nodes to their child properties | ✓ SATISFIED | `connectorPath` wired in `viewProperties`, `viewItems`, and Array branch; `viewMulti` passes parent coords |
| VIS-02 | 04-01-PLAN.md | `$ref` nodes have a distinct visual style distinguishing them from inline schemas | ✓ SATISFIED | `strokeDasharray "5 3"` conditionally applied in `iconRect` for `IRef _` pattern |

No orphaned requirements: both VIS-01 and VIS-02 are claimed by 04-01-PLAN.md and verified in the codebase.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `src/Render/Svg.elm` | 660 | `SvgA.strokeLinecap "Round"` (capital R) in `separatorGraph` | ℹ️ Info | SVG `stroke-linecap` values are case-sensitive lowercase (`round`); this pre-existing inconsistency is in the separator line, not in `connectorPath` (which correctly uses lowercase `"round"`). Does not affect this phase's deliverables. |

No blockers or warnings found in phase-modified code. The single info item is pre-existing and unrelated to connector lines or dashed borders.

### Human Verification Required

#### 1. Connector Lines Visible in Browser

**Test:** Build the app (`elm make src/Main.elm --output=public/elm.js --optimize && cp src/main.css public/main.css`), open `public/index.html`, select the "Address" example
**Expected:** Smooth cubic bezier curves rendered in `#8baed6` color at 1.5px width connect the root object pill to each of its property child pills
**Why human:** SVG curve rendering and color appearance require visual inspection

#### 2. Connector Lines Respond to Expand/Collapse

**Test:** With the "Address" example loaded, click the root object node to collapse, then expand
**Expected:** Connector lines disappear entirely when collapsed; reappear connecting to all properties when expanded. No stale or lingering connector artifacts.
**Why human:** Interactive DOM state change requires browser session

#### 3. $ref Dashed Border Visually Distinct

**Test:** Load a schema with $ref nodes (e.g., select an example containing definitions/references); inspect pill borders
**Expected:** $ref pills display a dashed border; object/string/array/number pills display solid borders
**Why human:** Stroke attribute is set; visual rendering difference requires eye confirmation

#### 4. Cycle Pill Dashed Border

**Test:** If a self-referencing schema is available, expand until a cycle pill appears
**Expected:** The cycle indicator pill (showing name + ↺ symbol) also has a dashed border matching $ref pills
**Why human:** Requires a schema with circular $ref to trigger the cycle code path in the browser

### Gaps Summary

No code gaps. All five observable truths are verified at all four levels (existence, substantive implementation, wiring, and data-flow). Both VIS-01 and VIS-02 requirements are satisfied. The phase is blocked only on human visual verification of browser rendering — which is expected and noted in the PLAN as a `checkpoint:human-verify` gate.

---

_Verified: 2026-04-06T10:00:00Z_
_Verifier: Claude (gsd-verifier)_
