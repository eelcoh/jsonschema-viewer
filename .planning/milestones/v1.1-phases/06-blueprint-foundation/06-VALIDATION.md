---
phase: 6
slug: blueprint-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | elm-test |
| **Config file** | elm.json (test-dependencies section) |
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
| 06-01-01 | 01 | 1 | VIS-01 | compile | `elm make src/Main.elm --output=/dev/null` | ✅ | ⬜ pending |
| 06-01-02 | 01 | 1 | VIS-01 | unit | `elm-test` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Dark background visible | VIS-01 | Visual appearance | Open public/index.html, verify navy (#1a2332) background renders |
| Text contrast legible | VIS-01 | Visual perception | Verify all node text readable against dark background |
| Node borders visible | VIS-01 | Visual perception | Verify outlined nodes distinguishable on dark background |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
