---
phase: 7
slug: node-design-and-information-density
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | elm-explorations/test 2.0.0 |
| **Config file** | none — elm-test discovers tests/ directory automatically |
| **Quick run command** | `elm-test` |
| **Full suite command** | `elm-test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `elm-test`
- **After every plan wave:** Run `elm-test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | NODE-01 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 07-01-02 | 01 | 1 | NODE-02 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 07-01-03 | 01 | 1 | NODE-02 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 07-01-04 | 01 | 1 | INFO-03 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 07-01-05 | 01 | 1 | INFO-03 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 07-02-01 | 02 | 2 | INFO-01 | manual | visual inspection | N/A | ⬜ pending |
| 07-02-02 | 02 | 2 | INFO-02 | manual | visual inspection | N/A | ⬜ pending |
| 07-02-03 | 02 | 2 | INFO-03 | manual | visual inspection | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/Tests.elm` — add `iconForString` dispatch tests covering all format variants (Email, DateTime, Hostname, Ipv4, Ipv6, Uri, Custom)
- [ ] `tests/Tests.elm` — add test for enum priority over format in `iconForString`
- [ ] `tests/Tests.elm` — add test for `borderColorForRequired` / required border color selection

*Existing infrastructure covers framework installation — elm-test is already configured.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Required properties show amber border | NODE-01 | SVG visual rendering cannot be unit tested | Load example schema with required/optional properties; verify amber vs default border |
| Format icons display correct text | NODE-02 | SVG visual rendering | Load schema with string format fields; verify icon text matches format |
| Hover overlay appears on mouseenter | INFO-01, INFO-02, INFO-03 | Browser interaction required | Hover over node with description/constraints/enum; verify overlay appears |
| Description shows in full in overlay | INFO-01 | Visual verification of text rendering | Hover over node with long description; verify no truncation |
| Constraints display in overlay | INFO-02 | Visual verification | Hover over numeric/string node with min/max; verify constraint rows |
| Enum values display in overlay | INFO-03 | Visual verification | Hover over enum node; verify values listed in overlay |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
