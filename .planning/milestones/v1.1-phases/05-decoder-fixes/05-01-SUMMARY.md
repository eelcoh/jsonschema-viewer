---
phase: 05-decoder-fixes
plan: 01
subsystem: decoder
tags: [elm, json-schema, decoder, $defs, $ref, combinator]

requires: []
provides:
  - CombinatorKind type and combinator field on BaseSchema
  - $defs support in definitionsDecoder (merged with definitions)
  - $ref normalization from #/$defs/ to #/definitions/
  - combinatorDecoder helper for typed schema decoders
  - Decoder round-trip tests for DEC-01 and DEC-02
affects: [05-02, render, svg]

tech-stack:
  added: []
  patterns:
    - "readDefs helper reads both definitions and $defs keys via Dict.union"
    - "combinatorDecoder probes oneOf/anyOf/allOf as last pipeline step in typed decoders"
    - "normalizeRef rewrites $defs refs to definitions prefix at decode time"

key-files:
  created:
    - tests/DecoderTests.elm
  modified:
    - src/Json/Schema.elm
    - src/Json/Schema/Decode.elm

key-decisions:
  - "Dict.union left-bias means definitions wins over $defs on key conflict"
  - "normalizeRef applied at decode-time so rest of app only sees #/definitions/ paths"
  - "combinator field is Maybe (CombinatorKind, List Schema) on BaseSchema — all typed variants get it"

patterns-established:
  - "BaseSchema extensible record pattern now includes combinator field"
  - "combinatorDecoder via custom pipeline step — reusable across all typed decoders"

requirements-completed: [DEC-01, DEC-02]

duration: ~15min
completed: 2026-04-11
---

# Plan 05-01: Decoder Model + Decode Fixes Summary

**CombinatorKind type, $defs/definitions merge, $ref normalization, and combinator probing across all typed decoders with 7 round-trip tests**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-11T14:05:00Z
- **Completed:** 2026-04-11T14:20:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Added CombinatorKind type (OneOfKind, AnyOfKind, AllOfKind) and combinator field to BaseSchema — all typed schemas now carry optional combinator data
- Extended definitionsDecoder with readDefs helper that reads both "definitions" and "$defs" keys, merging via Dict.union (definitions wins on conflict)
- Added normalizeRef to rewrite #/$defs/ refs to #/definitions/ at decode time
- Added combinatorDecoder helper piped into all 8 typed decoder arms via custom pipeline step
- Created DecoderTests.elm with 7 tests covering $defs normalization, $ref rewriting, definitions merge, combined type+combinator, pure combinator, array+anyOf, and plain object

## Task Commits

Each task was committed atomically:

1. **Task 1: Add CombinatorKind type, combinator field to BaseSchema** - `079a9b9` (feat)
2. **Task 2: Extend definitionsDecoder, add normalizeRef, add combinatorDecoder** - `39dab9b` (feat)
3. **Task 3: Write decoder tests for DEC-01 and DEC-02** - uncommitted (tests/DecoderTests.elm exists, all 31 tests pass)

## Files Created/Modified
- `src/Json/Schema.elm` - CombinatorKind type, combinator field on BaseSchema, updated all constructors
- `src/Json/Schema/Decode.elm` - readDefs helper, normalizeRef, combinatorDecoder, updated all typed decoders
- `tests/DecoderTests.elm` - 7 decoder round-trip tests for DEC-01 and DEC-02

## Decisions Made
- Dict.union left-bias ensures definitions keys win over $defs on conflict (per D-02)
- normalizeRef applied at decode-time so all downstream code only sees #/definitions/ paths
- baseCombinatorSchema sets combinator = Nothing (pure combinator schemas don't nest)

## Deviations from Plan
None - plan executed as written.

## Issues Encountered
Session ended before SUMMARY.md creation — completed in subsequent session.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- CombinatorKind type and combinator field available for Plan 05-02 (SVG renderer)
- All typed schemas now carry combinator data for rendering

---
*Phase: 05-decoder-fixes*
*Completed: 2026-04-11*
