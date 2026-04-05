---
phase: 02
slug: correct-rendering
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-04
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | elm-test 0.19.1-revision17 |
| **Config file** | `elm.json` (test dependencies already configured) |
| **Quick run command** | `elm-test` |
| **Full suite command** | `elm-test && elm make src/Main.elm --output=/dev/null` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `elm-test`
- **After every plan wave:** Run `elm-test && elm make src/Main.elm --output=/dev/null`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 0 | SETUP | unit | `elm-test` | ✅ | ⬜ pending |
| 02-01-02 | 01 | 1 | REND-03 | compile+unit | `elm make src/Main.elm --output=/dev/null && elm-test` | ✅ | ⬜ pending |
| 02-01-03 | 01 | 1 | REND-01 | compile+unit | `elm make src/Main.elm --output=/dev/null && elm-test` | ✅ | ⬜ pending |
| 02-01-04 | 01 | 1 | REND-02 | compile+visual | `elm make src/Main.elm --output=/dev/null` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Remove deliberate `Expect.fail` test from `tests/Tests.elm`
- [ ] Verify `elm-test` runs green as baseline

*Existing elm-test infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| $ref renders definition name with distinct style | REND-01 | Visual SVG output | Load example with $ref, verify node shows definition name |
| SVG viewport fits full diagram | REND-02 | Visual sizing | Load large schema (Petstore), verify no clipping |
| Required props bold, optional normal | REND-03 | Visual weight | Load schema with required array, compare property styles |
| Circular $ref shows ↺ indicator | REND-01 | Visual + no-hang | Load schema with circular ref, verify no hang and ↺ shows |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
