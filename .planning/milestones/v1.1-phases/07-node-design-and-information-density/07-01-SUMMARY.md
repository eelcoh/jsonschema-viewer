---
phase: 07-node-design-and-information-density
plan: 01
subsystem: Render.Svg / Render.Theme
tags: [icons, required-border, enum-icon, format-icons, theme]
dependency_graph:
  requires: []
  provides: [iconForSchema, borderColorForRequired, Icon-extended, Theme-overlay-constants]
  affects: [src/Render/Svg.elm, src/Render/Theme.elm, tests/Tests.elm]
tech_stack:
  added: []
  patterns: [iconForSchema pure dispatch, borderColorForRequired theme lookup, isRequired threading]
key_files:
  created: []
  modified:
    - src/Render/Theme.elm
    - src/Render/Svg.elm
    - tests/Tests.elm
decisions:
  - "Expose Icon(..) from Render.Svg to enable direct pattern match assertions in unit tests"
  - "Remove viewString/viewBool/viewFloat/viewInteger helpers in favor of direct iconRect+iconForSchema"
  - "Thread isRequired Bool through viewSchema rather than deriving from weight string to preserve type safety"
metrics:
  duration: ~15 minutes
  completed: "2026-04-15"
  tasks: 1
  files_modified: 3
---

# Phase 7 Plan 01: Pill Node Visual Extensions Summary

Extended the pill node rendering system with required/optional amber border distinction, format-as-type icons for StringFormat variants, and enum-overrides-type icon logic.

## What Was Built

**New Theme constants** (4): `requiredBorder` (#e8a020 amber), `overlayBg` (#0f1e30), `overlayBorder` (#3a5a7a), `overlayKeyText` (#8ab0d0) — the overlay constants are pre-positioned for Plan 02 hover tooltip work.

**Extended Icon type** with 8 new variants: `IEmail`, `IDateTime`, `IHostname`, `IIpv4`, `IIpv6`, `IUri`, `ICustom String`, `IEnum`.

**`iconForSchema : Schema -> Icon`** — pure helper that dispatches the correct icon from a schema value. Enum presence takes precedence over format (D-07 rule): any schema variant with `Just _` enum produces `IEnum`.

**`borderColorForRequired : Bool -> String`** — returns `Theme.requiredBorder` ("#e8a020") for required properties, `Theme.nodeBorder` ("#a0c4e8") for optional.

**`iconRect` parameter extension** — added `isRequired : Bool` as 4th parameter. Border color now dispatches via `borderColorForRequired isRequired` instead of hardcoded `Theme.nodeBorder`.

**`viewSchema` signature extension** — added `isRequired : Bool` parameter. Required status flows from `viewProperty` (which reads `Schema.Required`/`Schema.Optional`) through all call sites.

**Removed** `viewString`, `viewBool`, `viewFloat`, `viewInteger` helper functions — their callers now use `iconRect (iconForSchema schema) name weight isRequired coords` directly, which correctly selects format/enum icons.

## Tests Added (15 new tests, 46 total)

- `iconForSchema` tests for all 7 StringFormat variants (Email, DateTime, Hostname, Ipv4, Ipv6, Uri, Custom)
- `iconForSchema` test for plain String (no format) → `IStr`
- `iconForSchema` test for String with enum + format → `IEnum` (enum precedence)
- `iconForSchema` tests for Integer with/without enum → `IEnum`/`IInt`
- `iconForSchema` test for Number without enum → `IFloat`
- `iconForSchema` test for Boolean without enum → `IBool`
- `borderColorForRequired True` → "#e8a020"
- `borderColorForRequired False` → "#a0c4e8"

## Verification

- `elm-test`: 46 tests pass, 0 failed
- `elm make src/Main.elm --output=/dev/null`: 0 errors

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

**One minor adjustment:** Exposed `Icon(..)` from `Render.Svg` module to enable direct `IEmail`, `IEnum`, etc. comparisons in unit tests. Plan said "add to exposing list" for `iconForSchema` and `borderColorForRequired` but did not explicitly mention `Icon(..)`. Added it to satisfy the acceptance criterion "tests/Tests.elm contains test for IEmail result" with direct `Expect.equal IEmail` assertions rather than structural indirection.

## Known Stubs

None. All icon dispatch is wired end-to-end: `viewProperty` extracts `isRequired`, passes to `viewSchema`, which passes to `iconRect`, which calls `borderColorForRequired isRequired`. `iconForSchema schema` is called with the actual schema value, selecting correct icon at render time.

## Self-Check: PASSED

- `src/Render/Theme.elm` exists with `requiredBorder`, `overlayBg`, `overlayBorder`, `overlayKeyText`
- `src/Render/Svg.elm` exists with `iconForSchema`, `borderColorForRequired`, `IEmail`, `IEnum`
- `tests/Tests.elm` exists with `iconForSchema` in imports and `IEmail` test
- Commit ff21728 exists in git log
