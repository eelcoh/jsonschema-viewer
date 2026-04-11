---
phase: 05-decoder-fixes
verified: 2026-04-11T15:00:00Z
status: human_needed
score: 8/8 must-haves verified
human_verification:
  - test: "Load TypeBox example and verify $defs resolution renders expanded Address object"
    expected: "address property shows expanded Address object with street, city, zip -- not a $ref label"
    why_human: "Visual rendering correctness cannot be verified programmatically"
  - test: "Verify combined object+oneOf renders combinator pill below properties"
    expected: "TypeBox example shows |1| combinator pill below name/age/address properties with two child branches"
    why_human: "SVG layout and visual positioning require browser rendering"
  - test: "Verify existing examples (Arrays, Person, Nested) have no visual regressions"
    expected: "All three examples render identically to before Phase 5"
    why_human: "Visual regression detection requires human comparison"
---

# Phase 5: Decoder Fixes Verification Report

**Phase Goal:** Users can load modern JSON Schema documents (2020-12 and combined type+combinator) and see them rendered correctly
**Verified:** 2026-04-11T15:00:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can paste a JSON Schema 2020-12 document using $defs and see all definitions resolved and rendered | VERIFIED | `readDefs "$defs"` in Decode.elm:25-33 reads $defs; normalizeRef rewrites refs; test "$defs keys normalized" passes; TypeBox example uses $defs with $ref resolution |
| 2 | User can load a schema with type:"object" combined with oneOf/anyOf/allOf and see both properties and combinator variants | VERIFIED | combinatorDecoder probes oneOf/anyOf/allOf in all typed decoder arms; Object arm in Render/Svg.elm:254-281 renders combinator via viewMulti below properties; test "object with oneOf" passes |
| 3 | Loading a TypeBox or Zod-generated schema no longer silently drops definitions | VERIFIED | TypeBox example in Main.elm:457-493 uses $defs and combined type+oneOf; definitionsDecoder merges both "definitions" and "$defs" via Dict.union |
| 4 | $ref values pointing at #/$defs/Foo are rewritten to #/definitions/Foo during decode | VERIFIED | normalizeRef function at Decode.elm:37-42; test "$ref value rewritten" passes |
| 5 | Schema with both definitions and $defs merges both into a single Dict | VERIFIED | `map2 Dict.union (readDefs "definitions") (readDefs "$defs")` at Decode.elm:33; test "both definitions and $defs merged" passes with Dict.size == 2 |
| 6 | Schema with type:object and oneOf decodes as Object with combinator = Just (OneOfKind, ...) | VERIFIED | `custom combinatorDecoder` in object decoder arm (Decode.elm:68); test passes asserting Object variant with combinator |
| 7 | Pure combinator schema (no type field) still decodes as OneOf/AnyOf/AllOf | VERIFIED | Standalone combinator decoders unchanged (Decode.elm:128-147); test "pure oneOf still decodes as OneOf variant" passes |
| 8 | Combined schemas render combinator children in SVG | VERIFIED | Object arm extracts combinator and calls viewMulti (Svg.elm:240-284); Array arm similar (Svg.elm:286-334); simple types use withCombinator (Svg.elm:336-354) |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/Json/Schema.elm` | CombinatorKind type, combinator field on BaseSchema | VERIFIED | CombinatorKind at line 62-65, BaseSchema combinator field at line 73, all constructors accept combinator param |
| `src/Json/Schema/Decode.elm` | $defs support, $ref normalization, combinatorDecoder | VERIFIED | readDefs helper (25-33), normalizeRef (37-42), combinatorDecoder (46-52), custom combinatorDecoder in all 7 typed arms + ref arm |
| `src/Render/Svg.elm` | Combined schema rendering | VERIFIED | combinatorIcon (193-203), withCombinator (205-225), Object arm combinator rendering (254-281), Array arm (308-333), simple types (336-354) |
| `src/Main.elm` | TypeBox example schema | VERIFIED | ExampleTypeBox variant (line 21), button (line 230), exampleTypeBoxJson with $defs/$ref/oneOf (lines 457-493) |
| `tests/DecoderTests.elm` | Decoder round-trip tests for DEC-01 and DEC-02 | VERIFIED | 7 tests: 3 for DEC-01 ($defs normalization, $ref rewriting, merge), 4 for DEC-02 (combined object+oneOf, pure combinator, array+anyOf, plain object Nothing) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Decode.elm | Schema.elm | CombinatorKind import | WIRED | `import Json.Schema as Schema` + `Schema.CombinatorKind` used in combinatorDecoder return type and body |
| Decode.elm | definitionsDecoder | readDefs helper | WIRED | readDefs reads both "definitions" and "$defs", merged via Dict.union |
| DecoderTests.elm | Decode.elm | decodeString round-trip | WIRED | All 7 tests use `Json.Decode.decodeString Json.Schema.Decode.decoder` |
| Render/Svg.elm Object arm | viewMulti | combinator rendering | WIRED | Object arm calls viewMulti for combinator at line 274 |
| Main.elm ExampleTypeBox | Decode.elm | JSON decoded by decoder | WIRED | exampleContent dispatches to exampleTypeBoxJson; TextareaChanged/ExampleSelected both call decodeString Json.Schema.Decode.decoder |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| Render/Svg.elm | combinator field | Decoded from JSON via combinatorDecoder | Yes -- probes oneOf/anyOf/allOf fields | FLOWING |
| Main.elm | model.parsedSchema | decodeString Json.Schema.Decode.decoder | Yes -- decodes user input or example JSON | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full project compiles | `elm make src/Main.elm --output=/dev/null` | Success | PASS |
| All tests pass | `elm-test` | 31 passed, 0 failed | PASS |
| Commits exist | `git log 079a9b9 39dab9b` | Both commits found | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| DEC-01 | 05-01, 05-02 | User can load JSON Schema 2020-12 documents using $defs and see definitions resolved correctly | SATISFIED | readDefs reads $defs, normalizeRef rewrites refs, TypeBox example exercises both; 3 decoder tests pass |
| DEC-02 | 05-01, 05-02 | User can load schemas with combined type + combinator and see both properties and combinator variants rendered | SATISFIED | combinatorDecoder populates combinator field, Render/Svg renders combinator children via viewMulti; 4 decoder tests pass |

No orphaned requirements found -- REQUIREMENTS.md maps DEC-01 and DEC-02 to Phase 5, both claimed by plans 05-01 and 05-02.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | - | - | - | - |

No TODOs, FIXMEs, placeholders, empty implementations, or stub patterns detected in any modified files.

### Human Verification Required

### 1. TypeBox Example $defs Resolution

**Test:** Click "TypeBox" example button in the toolbar
**Expected:** The "address" property resolves to an expanded Address object with "street", "city", "zip" sub-properties (not a simple $ref label)
**Why human:** SVG rendering of expanded $ref definitions requires visual inspection in a browser

### 2. Combined Object+OneOf Layout

**Test:** With TypeBox example loaded, inspect the diagram below the properties
**Expected:** A |1| (oneOf) combinator pill appears below the name/age/address properties, with two child branches showing the admin and user role variants
**Why human:** Combinator pill positioning relative to properties requires visual layout verification

### 3. Existing Examples Regression Check

**Test:** Click Arrays, Person, and Nested example buttons in sequence
**Expected:** All three render identically to their appearance before Phase 5 changes
**Why human:** Visual regression detection cannot be automated without screenshot comparison

### Gaps Summary

No gaps found. All automated verification passes cleanly:
- Full project compiles without errors
- All 31 tests pass (24 existing + 7 new decoder tests)
- All artifacts exist, are substantive, and are properly wired
- Both DEC-01 and DEC-02 requirements are satisfied with implementation evidence
- No anti-patterns detected

The only remaining verification is human visual inspection of the rendered SVG output to confirm correct layout and no regressions.

---

_Verified: 2026-04-11T15:00:00Z_
_Verifier: Claude (gsd-verifier)_
