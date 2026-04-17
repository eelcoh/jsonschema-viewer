# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.1 — Professional Visuals

**Shipped:** 2026-04-17
**Phases:** 3 | **Plans:** 5 | **Tasks:** 9
**Timeline:** 2026-04-06 → 2026-04-17 (10 days)
**Git:** v1.0 → HEAD — 44 files changed, +8,633 / −1,081 lines

### What Was Built

- Decoder now handles JSON Schema 2020-12 — `$defs` merged with `definitions` and `$ref` normalized at decode time so modern TypeBox/Zod schemas render correctly (DEC-01)
- Combined `type` + combinator shapes render both structure and variants via a `CombinatorKind` field threaded through BaseSchema (DEC-02)
- Blueprint visual identity — dark navy (#1a2332) SVG canvas with dot-grid texture, outlined pill nodes, muted bezier connectors, centralized in a new `Render.Theme` module (VIS-01)
- Required-property distinction via amber (#e8a020) border in addition to bold font weight (NODE-01)
- Format-as-type icon dispatch (email, date-time, hostname, ipv4, ipv6, uri, custom) with enum precedence per D-07 (NODE-02)
- Hover overlay system surfacing description, constraints (min/max, length, pattern), and enum values on any node with metadata — implemented as fixed-position HTML overlay driven by mouse clientX/clientY (INFO-01, INFO-02, INFO-03)

### What Worked

- **Decoder-layer normalization.** Rewriting `$ref` from `#/$defs/…` to `#/definitions/…` at decode time meant the rest of the app was unaware of 2020-12 — zero downstream changes for DEC-01.
- **Dict.union left-bias for `definitions` ∪ `$defs`.** Single canonical dict downstream; no ambiguity in renderer or ref resolver.
- **Combinator as `Maybe (CombinatorKind, List Schema)` on BaseSchema.** Every typed variant got combinator support in one place — much cleaner than per-variant branching.
- **`ViewConfig` record threaded through recursive views.** Avoided adding 3 pass-through params (toggle, hover, unhover) at every recursive call site — one record beats three props.
- **`iconForSchema` pure dispatch.** Collapsed four `viewString/viewBool/viewFloat/viewInteger` helpers into a single function with correct enum/format precedence per D-07.
- **Plan split around Theme module.** Phase 6 shipping the Theme module before Phase 7's constants and borders meant no double-pass through coordinate-threading code.

### What Was Inefficient

- **Requirements checkboxes drifted from reality.** DEC-01 and DEC-02 stayed `[ ]` in REQUIREMENTS.md through milestone completion even though plans were marked `[x]` and PROJECT.md listed both as validated. Needed reconciliation during archival.
- **SVG overlay rework.** Plan 07-02 originally rendered the hover overlay inside the SVG viewBox — it fell outside the dynamic viewBox at runtime. Reworked as fixed-position HTML with mouse clientX/clientY. Worth capturing as a design-contract anti-pattern: SVG overlays depend on viewBox geometry that changes with diagram size.
- **Theme adoption incomplete.** Main.elm overlay still uses hardcoded `#0f1e30`, `#3a5a7a`, `#8ab0d0` instead of Theme.* references. Theme module exports 7 unused constants — design intent outran adoption.
- **STATE.md drifted.** At milestone completion STATE.md still read "Completed 07-02-PLAN.md Task 1, awaiting human-verify checkpoint" — stale by ~2 days. Not blocking but indicates plan-completion flow doesn't always update STATE reliably.

### Patterns Established

- **Decoder-layer normalization over downstream compatibility shims** — prefer to rewrite inputs once at the boundary rather than teach the renderer about multiple input shapes.
- **`ViewConfig` record for cross-cutting concerns in recursive views** — any future expansion (selection state, focus, etc.) should join this record, not add new pass-through parameters.
- **`iconForSchema` as the single icon-resolution function** — enum > format > baseType precedence is canonical; new icon variants extend this function, not add per-type view helpers.
- **Hover overlay pattern: HTML fixed-position driven by mouse coords** — SVG overlays inside viewBox are fragile; HTML overlay outside the SVG is the stable pattern for hover detail.
- **Required status as explicit `Bool` threaded through views** — don't derive from string weight; type-safety makes future border-color decisions simple.

### Key Lessons

1. **Sync traceability tables before archival.** REQUIREMENTS.md checkboxes can drift from phase summaries; either update at plan completion or run an audit sweep before `/gsd:complete-milestone`.
2. **Overlay rendering belongs outside SVG.** SVG content depends on viewBox geometry; for anything that should stay in-viewport regardless of diagram size, use HTML positioned absolutely.
3. **Theme module requires active adoption, not just existence.** Merely creating Theme constants doesn't remove literals downstream; subsequent plans must explicitly migrate, or literals accumulate.
4. **Tech-debt audit surfaces consistency gaps the plan contract doesn't.** The v1.1 audit found 3 items (hardcoded colors, orphan exports, Null-type hover gap) that passed every per-phase check because each phase's contract was satisfied — cross-cutting consistency needs the audit pass.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Tasks | Key Change |
|-----------|--------|-------|-------|------------|
| v1.0 MVP | 4 | 7 | — | Foundation build — paste/upload, $ref, expand/collapse, polish |
| v1.1 Professional Visuals | 3 | 5 | 9 | Visual system (Theme module) + metadata density (hover overlay) + decoder modernization |

### Cumulative Quality

| Milestone | Tests | LOC (Elm) | Decoder Coverage |
|-----------|-------|-----------|------------------|
| v1.0 | — | ~2,200 | draft-07 |
| v1.1 | 46 | 2,486 | draft-07 + 2020-12 (`$defs`, combined type+combinator) |

### Top Lessons (Verified Across Milestones)

1. **Normalize at the boundary, not downstream.** v1.0 coordinate-threading pattern kept layout math in one place; v1.1 `$ref` normalization kept ref-shape concerns in the decoder. Both avoided leaking representation choices through the system.
2. **Pure dispatch helpers over per-variant functions.** v1.1 `iconForSchema` (replacing four `viewString/viewBool/…` helpers) follows the same principle v1.0 used for path-based collapse state — one rule, applied uniformly.
