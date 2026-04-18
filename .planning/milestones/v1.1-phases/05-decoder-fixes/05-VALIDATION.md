---
phase: 5
slug: decoder-fixes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-11
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | elm-explorations/test 2.0.0 |
| **Config file** | `elm.json` (test-dependencies section) |
| **Quick run command** | `elm-test` |
| **Full suite command** | `elm-test` |
| **Estimated runtime** | ~1 second |

---

## Sampling Rate

- **After every task commit:** Run `elm-test`
- **After every plan wave:** Run `elm-test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 0 | DEC-01 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 0 | DEC-01 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 05-01-03 | 01 | 0 | DEC-01 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 05-01-04 | 01 | 0 | DEC-02 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 05-01-05 | 01 | 0 | DEC-02 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 05-01-06 | 01 | 0 | DEC-02 | unit | `elm-test` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/DecoderTests.elm` — stubs for DEC-01 (`$defs` decode, ref normalization, merge) and DEC-02 (combined schema decode, pure combinator unchanged)
- No framework install needed — elm-explorations/test 2.0.0 already declared in elm.json

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SVG renders combinator variants below properties | DEC-02 | Visual layout correctness | Paste combined type+combinator schema in UI, verify combinator pills appear below property children |
| TypeBox/Zod schema renders without dropped definitions | DEC-01 | End-to-end user workflow | Paste a TypeBox-generated schema using `$defs`, verify all `$ref` nodes resolve |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
