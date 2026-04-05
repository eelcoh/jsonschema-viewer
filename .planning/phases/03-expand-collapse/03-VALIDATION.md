---
phase: 3
slug: expand-collapse
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | elm-explorations/test 2.0.0 |
| **Config file** | none (elm-test auto-discovers) |
| **Quick run command** | `elm make src/Main.elm --output=/dev/null` |
| **Full suite command** | `elm-test` |
| **Estimated runtime** | ~164 ms |

---

## Sampling Rate

- **After every task commit:** Run `elm make src/Main.elm --output=/dev/null`
- **After every plan wave:** Run `elm-test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 0 | INTR-01 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 0 | INTR-01 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 0 | INTR-01 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 03-xx-xx | xx | 1+ | INTR-01 | compile | `elm make src/Main.elm --output=/dev/null` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/RenderHelpers.elm` — extend with tests for `toggleInSet` helper, path key construction, path key uniqueness across depths

*Existing `RenderHelpers.elm` already covers `viewBoxString`, `extractRefName`, `isCircularRef`, `refLabel`, `fontWeightForRequired` — extend, don't create new file.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Click object node toggles children visibility | INTR-01 | SVG click interaction requires browser | Load example schema, click object pill, verify children hide/show |
| Click array node toggles items visibility | INTR-01 | SVG click interaction requires browser | Load example with array, click array pill, verify items hide/show |
| Collapsed node correctly reflows layout | INTR-01 | Layout reflow requires visual verification | Collapse mid-tree node, verify no overlapping nodes |
| Independent toggle at different depths | INTR-01 | Requires interaction sequence | Collapse node at depth 2, verify same-name node at depth 1 unaffected |
| $ref node expands inline | INTR-01 | SVG click + ref resolution requires browser | Click $ref pill, verify definition fields appear inline |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
