---
phase: 1
slug: foundation-and-input
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-04
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | elm-explorations/test 1.0.0 |
| **Config file** | none — create-elm-app auto-discovers `tests/` |
| **Quick run command** | `elm make src/Main.elm --output=/dev/null` |
| **Full suite command** | `elm make src/Main.elm --output=/dev/null --optimize && elm-test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `elm make src/Main.elm --output=/dev/null`
- **After every plan wave:** Run `elm make src/Main.elm --output=/dev/null --optimize && elm-test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | FOUND-01 | smoke | `elm make src/Main.elm --output=/dev/null --optimize` | N/A — command | ⬜ pending |
| 01-01-02 | 01 | 1 | FOUND-02 | smoke | `elm make src/Main.elm --output=/dev/null` | N/A — command | ⬜ pending |
| 01-02-01 | 02 | 2 | INPUT-01 | unit | `elm-test tests/InputTests.elm` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 2 | INPUT-02 | unit | `elm-test tests/InputTests.elm` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/InputTests.elm` — stubs for INPUT-01 (TextareaChanged → model update), INPUT-02 (FileContentLoaded → model update)

*Existing `tests/Tests.elm` has a placeholder failing test — not a blocker.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Drag-and-drop file onto textarea zone | INPUT-02 | Browser event wiring cannot be tested in elm-test | 1. Open app in browser 2. Drag a .json file onto textarea area 3. Verify textarea content updates and diagram renders |
| Textarea panel collapse/expand | D-02 | Visual layout behavior | 1. Click collapse control 2. Verify textarea hidden and diagram expands 3. Click expand to restore |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
