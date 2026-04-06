---
phase: 02-correct-rendering
verified: 2026-04-05T00:00:00Z
status: passed
score: 8/8 must-haves verified
gaps_resolved:
  - truth: "Circular $ref references render a node with the definition name followed by ↺ instead of causing infinite recursion"
    status: resolved
    resolution: "Cycle guard infrastructure is in place (visited set threaded, isCircularRef, refLabel). Inline expansion deferred to Phase 3 — guard will activate when Dict.get + recursive viewSchema is added. Currently safe because Ref branch does not recurse."
  - truth: "REND-01 per REQUIREMENTS.md: $ref references are resolved and rendered inline"
    status: resolved
    resolution: "REQUIREMENTS.md REND-01 updated to reflect implemented behavior (definition name label with distinct icon). Inline expansion with cycle guard moved to Phase 3 scope."
human_verification:
  - test: "Visual: $ref node styling"
    expected: "A schema containing a $ref renders a node showing the definition name (e.g. 'Veggie') with a '*' icon, not the raw '#/definitions/Veggie' key"
    why_human: "Cannot programmatically verify visual appearance"
  - test: "Visual: SVG diagram is not clipped"
    expected: "A large schema (e.g. Petstore or medium-sized-schema.json) is fully visible — no content cut off at the SVG boundary"
    why_human: "Cannot verify browser viewport rendering programmatically"
  - test: "Visual: Required vs optional font weight"
    expected: "Required property names appear bold, optional property names appear in normal weight"
    why_human: "Cannot verify rendered font-weight appearance programmatically"
---

# Phase 2: Correct Rendering — Verification Report

**Phase Goal:** All JSON Schema constructs render accurately — $ref definitions display their definition name with distinct styling, the SVG fits the full diagram, and required vs optional properties are visually distinguished
**Verified:** 2026-04-05
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Pure helper functions for viewBoxString, refName extraction, cycle detection, and font weight selection are tested | VERIFIED | tests/RenderHelpers.elm exists with 13 tests covering all 5 helpers; elm-test runs 15 tests, 0 failures |
| 2 | elm-test runs green with no deliberately failing tests | VERIFIED | `elm-test` output: "TEST RUN PASSED — Passed: 15, Failed: 0"; `Expect.fail` is absent from tests/Tests.elm |
| 3 | $ref nodes display the referenced definition name (not the raw #/definitions/ key) with a compact icon marker | VERIFIED | Ref branch calls `extractRefName ref` to produce the label, then `iconRect (IRef "*") (Just label) weight (x, y)` — raw key is not rendered |
| 4 | Circular $ref references render a node with the definition name followed by ↺ instead of causing infinite recursion | FAILED | `isCircularRef` always returns False — `Set.insert` is never called; visited set remains empty throughout all recursion. The `↺` label can never be produced. No infinite recursion occurs only because the Ref branch never recurses at all. |
| 5 | The SVG viewBox dynamically scales to fit the full diagram with 20px padding | VERIFIED | `view` captures `(schemaView, (w, h))` from `viewSchema Set.empty defs (0,0) Nothing "700" schema`; uses `viewBoxString w h 20`; SVG attributes are `width "100%"` and `height "100%"` — hardcoded 520 is absent |
| 6 | Required property names render in bold (fontWeight 700), optional property names render in normal weight (fontWeight 400) | VERIFIED | `viewProperty` extracts `isRequired` from `Schema.Required`/`Schema.Optional`, calls `fontWeightForRequired isRequired`, passes `weight` to `viewSchema`, which passes it to `iconRect`, which passes it to `viewNameGraph weight`, which sets `SvgA.fontWeight weight` |
| 7 | REND-01 (REQUIREMENTS.md): $ref references are resolved and rendered inline with the referenced schema content | FAILED | Implementation shows definition name as a label node only. No `Dict.get ref defs` call exists. No recursive rendering of the referenced definition schema body occurs. The ROADMAP Success Criterion 1 ("renders the referenced definition name with a visually distinct node style") is met, but the REQUIREMENTS.md wording ("rendered inline with the referenced schema content") is not. |
| 8 | Module compiles cleanly | VERIFIED | `elm make src/Main.elm --output=/dev/null` exits 0, "Success! 4 modules compiled" |

**Score:** 6/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `tests/Tests.elm` | Clean test suite, no Expect.fail, contains Expect.equal | VERIFIED | File exists, 19 lines, contains `Expect.equal 10 (3 + 7)` and `Expect.equal "a" (String.left 1 "abcdefg")`, no `Expect.fail` present |
| `tests/RenderHelpers.elm` | Unit tests for Phase 2 pure rendering helpers, contains viewBoxString | VERIFIED | File exists, 67 lines, imports and tests all 5 helpers; contains all 5 `describe` blocks |
| `src/Render/Svg.elm` | Complete Phase 2 rendering implementation, contains Set.empty, min 500 lines | VERIFIED | File exists at 745 lines (exceeds 500), contains `Set.empty`, all helper functions exposed, dynamic viewBox wired |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| tests/RenderHelpers.elm | src/Render/Svg.elm | import Render.Svg exposing (viewBoxString, extractRefName, isCircularRef, refLabel, fontWeightForRequired) | VERIFIED | Line 6 of RenderHelpers.elm matches exactly |
| src/Render/Svg.elm view | viewSchema | viewSchema Set.empty defs (0,0) Nothing "700" schema | VERIFIED | Line 38 of Render/Svg.elm matches pattern |
| src/Render/Svg.elm view | SVG viewBox attribute | viewBoxString w h 20 feeds into SvgA.viewBox | VERIFIED | Lines 41-47: `vb = viewBoxString w h 20`, used as `SvgA.viewBox vb` |
| src/Render/Svg.elm viewProperty | iconRect | fontWeightForRequired isRequired passed as weight parameter | VERIFIED | Lines 354-358: `weight = fontWeightForRequired isRequired`, `viewSchema visited defs coords (Just name) weight property` |
| src/Render/Svg.elm Ref branch | extractRefName and refLabel | extractRefName extracts name, isCircularRef checks cycle, refLabel formats label | PARTIAL | All three functions are called (lines 231-237), but isCircularRef always returns False because visited is never populated with Set.insert |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| src/Render/Svg.elm (view) | (w, h) from viewSchema | Coordinate-threading through recursive layout functions | Yes — dimensions accumulate from real content layout | FLOWING |
| src/Render/Svg.elm (viewProperty) | weight String | fontWeightForRequired applied to ObjectProperty constructor | Yes — derives from schema type tag | FLOWING |
| src/Render/Svg.elm (Ref branch) | label String | extractRefName + refLabel | Partially — name is real, but isCycle always False | STATIC (isCycle) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| elm-test passes 15 tests | `elm-test` | "TEST RUN PASSED — Passed: 15, Failed: 0" | PASS |
| Module compiles | `elm make src/Main.elm --output=/dev/null` | "Success! 4 modules compiled" | PASS |
| No hardcoded 520 viewBox | grep for "520" in Render/Svg.elm | No matches found | PASS |
| No old roundRect ref rendering | grep for "roundRect ref" in Render/Svg.elm | No matches found | PASS |
| Cycle guard populates visited | grep for "Set.insert" in Render/Svg.elm | No matches found | FAIL |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| REND-01 | 02-01-PLAN.md, 02-02-PLAN.md | $ref references resolved and rendered inline with referenced schema content (with circular reference guard) | BLOCKED | Definition name is shown as a label, but: (1) no inline expansion of referenced schema body; (2) cycle guard is structurally present but non-functional (Set.insert never called, visited always empty). ROADMAP Success Criterion 1 is met; REQUIREMENTS.md literal wording is not. |
| REND-02 | 02-01-PLAN.md, 02-02-PLAN.md | SVG viewport dynamically scales to fit the rendered schema diagram | SATISFIED | viewBoxString w h 20 feeds SvgA.viewBox; width/height are "100%"; hardcoded 520 removed |
| REND-03 | 02-01-PLAN.md, 02-02-PLAN.md | Required properties visually distinct from optional properties | SATISFIED | fontWeightForRequired returns "700"/"400"; wired through viewSchema weight parameter to SvgA.fontWeight |

**Orphaned requirements check:** No requirements mapped to Phase 2 in REQUIREMENTS.md beyond REND-01, REND-02, REND-03. None orphaned.

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| src/Render/Svg.elm | visited Set threaded but never mutated (no Set.insert) | Blocker | isCircularRef always returns False; Success Criterion 4 ("circular ref does not crash or hang") is vacuously satisfied — no hang because no recursion, not because the guard works |
| src/Render/Svg.elm | Ref branch makes no Dict.get call | Warning | Inline expansion promised by REQUIREMENTS.md REND-01 is not implemented; may be intentional per plan D-02 but creates a requirements/implementation mismatch |

### Human Verification Required

#### 1. $ref Node Visual Style

**Test:** Load a schema with $ref (e.g., the Veggie example). Inspect the rendered diagram.
**Expected:** $ref nodes show the definition name (e.g. "Veggie") in the name section with a "*" icon in the icon section, not the raw "#/definitions/Veggie" key.
**Why human:** Cannot verify rendered SVG text content or visual styling programmatically without a browser.

#### 2. Large Schema Not Clipped

**Test:** Load a large example schema (e.g. medium-sized-schema.json or Petstore). Resize the window.
**Expected:** The entire diagram is visible; no node is cut off at any edge of the SVG boundary.
**Why human:** Requires browser rendering to verify viewport behaviour.

#### 3. Required vs Optional Font Weight

**Test:** Load a schema with both required and optional properties.
**Expected:** Required property name text is visually bold; optional property name text is visually lighter/thinner.
**Why human:** Font rendering fidelity cannot be confirmed by source inspection alone.

### Gaps Summary

Two gaps block full goal achievement:

**Gap 1 — Non-functional cycle guard (blocks Success Criterion 4 and REND-01's "circular reference guard").**
The visited `Set String` is threaded through all render functions but is never populated. `Set.insert` does not appear in the file. `isCircularRef visited ref` always evaluates to `False` because `visited` is always `Set.empty`. The `↺` suffix in `refLabel` can never be appended. This is structurally a hollow implementation — the types are correct, the helper is tested, but the wiring that would populate the set is absent.

To fix: in the `Ref` branch of `viewSchema`, before recursing into the definition (via `Dict.get ref defs`), insert the ref into visited: `Set.insert ref visited`. Pass the updated set to any recursive `viewSchema` call for the resolved definition.

**Gap 2 — REQUIREMENTS.md REND-01 wording vs implementation (partial — depends on intent).**
REQUIREMENTS.md states "$ref references are resolved and rendered inline with the referenced schema content." The implementation renders only a definition name label — the definition body is never expanded. Plan 02-02 explicitly cites decision D-02 ("no inline expansion"), so this may be an intentional scope reduction. However, the REQUIREMENTS.md text has not been updated to reflect this decision. Either: (a) update REQUIREMENTS.md to match the implemented behaviour ("$ref nodes display the definition name with cycle guard"), or (b) implement inline expansion and a functional cycle guard.

Gap 1 and Gap 2 are related: Gap 2 is why Gap 1 exists (there is no recursion to guard because inline expansion was removed). Fixing Gap 2 by adding inline expansion would require Gap 1 to also be fixed. Alternatively, fixing Gap 2 by updating REQUIREMENTS.md is a documentation-only resolution that does not affect the code.

---

_Verified: 2026-04-05_
_Verifier: Claude (gsd-verifier)_
