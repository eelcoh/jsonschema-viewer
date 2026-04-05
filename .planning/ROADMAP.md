# Roadmap: JSON Schema Viewer

## Overview

Starting from a working proof-of-concept with hardcoded schemas, this milestone evolves the app into a usable interactive viewer. Phase 1 cleans up build blockers and wires up user input. Phase 2 makes rendering correct for all schema constructs. Phase 3 adds the core interactive capability — expand/collapse. Phase 4 completes the visual experience with connector lines and distinct node styles.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation and Input** - Remove build blockers and wire up user-controlled schema input
- [ ] **Phase 2: Correct Rendering** - Fix SVG viewport, $ref inline expansion, and required/optional distinction
- [ ] **Phase 3: Expand/Collapse** - Make schema nodes interactively collapsible and expandable
- [ ] **Phase 4: Visual Polish** - Add connector lines and distinct visual styles for $ref nodes

## Phase Details

### Phase 1: Foundation and Input
**Goal**: Users can paste or upload their own JSON Schema and see it rendered; the app compiles cleanly under --optimize
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, INPUT-01, INPUT-02
**Success Criteria** (what must be TRUE):
  1. Running `elm make src/Main.elm --output=/dev/null --optimize` completes without errors
  2. User can paste a JSON Schema into a textarea and the diagram updates immediately
  3. User can pick a .json file from their filesystem and the diagram renders its schema
  4. When the pasted or uploaded text is not valid JSON Schema, a readable error message is shown instead of a blank screen
**Plans**: TBD

### Phase 2: Correct Rendering
**Goal**: All JSON Schema constructs render accurately — $ref definitions display their definition name with distinct styling, the SVG fits the full diagram, and required vs optional properties are visually distinguished
**Depends on**: Phase 1
**Requirements**: REND-01, REND-02, REND-03
**Success Criteria** (what must be TRUE):
  1. A schema containing a $ref renders the referenced definition name with a visually distinct node style, not just a raw key
  2. A large schema (e.g., Petstore Swagger components) is fully visible — no content clipped by the SVG boundary
  3. Required properties appear visually distinct from optional properties (bold name vs normal weight)
  4. A $ref that references itself (or forms a cycle) does not crash or hang the browser
**Plans**: 2 plans
Plans:
- [x] 02-01-PLAN.md — Extract and test pure rendering helper functions
- [x] 02-02-PLAN.md — Implement $ref rendering, dynamic viewBox, and required/optional distinction
**UI hint**: yes

### Phase 3: Expand/Collapse
**Goal**: Users can click any container node (object, array, combinator) to collapse or expand its children, making large schemas navigable. $ref definitions are expanded inline with cycle detection guard.
**Depends on**: Phase 2
**Requirements**: INTR-01
**Success Criteria** (what must be TRUE):
  1. Clicking an object node hides its properties; clicking again reveals them
  2. Clicking an array node hides its items schema; clicking again reveals it
  3. Collapsing a node correctly reflows the layout — no overlapping nodes or stale positions
  4. Two nodes with the same property name at different depths toggle independently
  5. A $ref node expands to show the referenced definition's fields inline (using the visited-set cycle guard from Phase 2)
**Plans**: 2 plans
Plans:
- [x] 03-01-PLAN.md — Update Render.Svg with path threading, conditional rendering, clickableGroup, and $ref inline expansion
- [x] 03-02-PLAN.md — Wire Main.elm (Model, Msg, update, view) and browser verification
**UI hint**: yes

### Phase 4: Visual Polish
**Goal**: The diagram communicates tree structure clearly through connector lines between parent and child nodes, and $ref nodes are visually distinguishable from inline schema nodes
**Depends on**: Phase 3
**Requirements**: VIS-01, VIS-02
**Success Criteria** (what must be TRUE):
  1. Lines connect each parent node to each of its child property nodes
  2. Connector lines appear and disappear correctly when nodes are expanded and collapsed
  3. $ref nodes have a visually distinct style (e.g., dashed border or link icon) compared to inline schema nodes
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation and Input | 1/2 | In Progress|  |
| 2. Correct Rendering | 1/2 | In Progress|  |
| 3. Expand/Collapse | 2/2 | In Progress|  |
| 4. Visual Polish | 0/TBD | Not started | - |
