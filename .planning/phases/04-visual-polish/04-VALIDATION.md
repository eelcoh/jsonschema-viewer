---
phase: 4
slug: visual-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | elm-explorations/test 2.0.0 |
| **Config file** | none (elm-test convention-based) |
| **Quick run command** | `elm make src/Main.elm --output=/dev/null` |
| **Full suite command** | `elm-test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `elm make src/Main.elm --output=/dev/null`
- **After every plan wave:** Run `elm-test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | VIS-01 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | VIS-01 | compile | `elm make src/Main.elm --output=/dev/null` | ✅ | ⬜ pending |
| 04-01-03 | 01 | 1 | VIS-02 | unit | `elm-test` | ❌ W0 | ⬜ pending |
| 04-01-04 | 01 | 1 | VIS-02 | compile | `elm make src/Main.elm --output=/dev/null` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/Tests.elm` — add `connectorPath` coordinate arithmetic tests
- [ ] `tests/Tests.elm` — add `iconRect` dashed-border conditional tests (if pure helpers are extractable)

*Existing `tests/Tests.elm` exists with stub tests. New test cases are additions, not a new file.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Connector lines render between parent and child pills | VIS-01 | SVG visual output cannot be inspected via elm-test | Open `public/index.html` with Address example schema; verify curved lines from parent right-center to child left-center |
| Connector lines disappear when nodes collapse | VIS-01 | Requires interactive browser session | Click parent node to collapse; verify connector lines vanish |
| $ref nodes have dashed border | VIS-02 | SVG border style requires visual check | Open Address schema; verify $ref pills have dashed borders while inline pills have solid borders |
| Cycle pill has dashed border | VIS-02 | SVG border style requires visual check | Open recursive schema example; verify cycle indicator pill has dashed border |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
