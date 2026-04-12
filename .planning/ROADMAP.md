# Roadmap: JSON Schema Viewer

## Milestones

- **v1.0 Interactive JSON Schema Viewer** — Phases 1-4 (shipped 2026-04-06)
- **v1.1 Professional Visuals** — Phases 5-7 (in progress)

## Phases

<details>
<summary>v1.0 Interactive JSON Schema Viewer (Phases 1-4) — SHIPPED 2026-04-06</summary>

- [x] Phase 1: Foundation and Input (2/2 plans) — Remove build blockers, wire up paste/upload input
- [x] Phase 2: Correct Rendering (2/2 plans) — $ref display, dynamic viewBox, required/optional distinction
- [x] Phase 3: Expand/Collapse (2/2 plans) — Interactive collapse/expand, inline $ref expansion, cycle guard
- [x] Phase 4: Visual Polish (1/1 plan) — Connector lines, dashed $ref borders

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

### v1.1 Professional Visuals (In Progress)

**Milestone Goal:** Transform the diagram from a proof-of-concept look into a professional blueprint-style technical diagram with richer schema information and broader format support.

- [ ] **Phase 5: Decoder Fixes** - Correct $defs resolution and combined type+combinator rendering
- [x] **Phase 6: Blueprint Foundation** - Dark navy background with Theme module and color-safe contrast (completed 2026-04-12)
- [ ] **Phase 7: Node Design and Information Density** - Visual property markers, format badges, inline descriptions, constraints, and enum values

## Phase Details

### Phase 5: Decoder Fixes
**Goal**: Users can load modern JSON Schema documents (2020-12 and combined type+combinator) and see them rendered correctly
**Depends on**: Phase 4
**Requirements**: DEC-01, DEC-02
**Success Criteria** (what must be TRUE):
  1. User can paste a JSON Schema 2020-12 document using `$defs` and see all definitions resolved and rendered
  2. User can load a schema with `type: "object"` combined with `oneOf`/`anyOf`/`allOf` and see both the object properties and combinator variants in the diagram
  3. Loading a TypeBox or Zod-generated schema no longer silently drops definitions
**Plans:** 2 plans
Plans:
- [x] 05-01-PLAN.md — Types + decoder: CombinatorKind, $defs support, $ref normalization, combinator field extraction, decoder tests
- [x] 05-02-PLAN.md — Renderer: combined schema rendering, TypeBox example, visual verification

### Phase 6: Blueprint Foundation
**Goal**: Users see the diagram on a dark navy blueprint background with a centralized Theme system that sets contrast requirements for all subsequent visual work
**Depends on**: Phase 5
**Requirements**: VIS-01
**Success Criteria** (what must be TRUE):
  1. User sees the entire diagram rendered on a dark navy background (approximately #1a2332)
  2. All existing node text and borders remain legible with sufficient contrast on the dark background
  3. A `Render.Theme` module exists that centralizes all visual constants — subsequent phases change values in one place
**Plans:** 1/1 plans complete
Plans:
- [x] 06-01-PLAN.md — Theme module, SVG color migration + background/grid, CSS dark adaptation

### Phase 7: Node Design and Information Density
**Goal**: Users can distinguish required from optional properties at a glance and read schema metadata (descriptions, constraints, formats, enums) directly on diagram nodes
**Depends on**: Phase 6
**Requirements**: NODE-01, NODE-02, INFO-01, INFO-02, INFO-03
**Success Criteria** (what must be TRUE):
  1. User can see a clear asterisk or badge on required property nodes, distinct from optional properties beyond font weight alone
  2. User can see string format annotations (email, date-time, uri, etc.) displayed as a compact badge on string nodes that declare a format
  3. User can read a node's description as secondary text when the schema has a `description` field
  4. User can see numeric and length constraints (min/max value, min/max length, pattern) displayed in compact notation on nodes that declare them
  5. User can see enum values displayed on nodes that define an `enum` field
**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation and Input | v1.0 | 2/2 | Complete | 2026-04-03 |
| 2. Correct Rendering | v1.0 | 2/2 | Complete | 2026-04-04 |
| 3. Expand/Collapse | v1.0 | 2/2 | Complete | 2026-04-05 |
| 4. Visual Polish | v1.0 | 1/1 | Complete | 2026-04-06 |
| 5. Decoder Fixes | v1.1 | 0/2 | In progress | - |
| 6. Blueprint Foundation | v1.1 | 1/1 | Complete   | 2026-04-12 |
| 7. Node Design and Information Density | v1.1 | 0/? | Not started | - |
