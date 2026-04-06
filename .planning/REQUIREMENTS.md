# Requirements: JSON Schema Viewer

**Defined:** 2026-04-03
**Core Value:** Users can visually navigate and understand the structure of any JSON Schema document through an interactive SVG diagram with expandable/collapsible nodes.

## v1.0 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Foundation

- [x] **FOUND-01**: `Debug.log` calls removed from `Render.Svg` so production builds work with `--optimize`
- [x] **FOUND-02**: App upgraded from `Browser.sandbox` to `Browser.element` to support user input and interactivity

### Input

- [x] **INPUT-01**: User can paste a JSON Schema document into a textarea and see it rendered as a diagram
- [x] **INPUT-02**: User can upload a JSON Schema file from their filesystem and see it rendered as a diagram

### Rendering

- [x] **REND-01**: `$ref` nodes display the referenced definition name with a distinct icon; inline expansion with circular reference guard deferred to Phase 3
- [x] **REND-02**: SVG viewport dynamically scales to fit the rendered schema diagram
- [x] **REND-03**: Required properties are visually distinct from optional properties

### Interactivity

- [x] **INTR-01**: User can click a node to expand or collapse its children (objects show/hide properties, arrays show/hide items)

### Visual

- [x] **VIS-01**: Connector lines link parent nodes to their child properties
- [x] **VIS-02**: `$ref` nodes have a distinct visual style (e.g., dashed border or link icon) distinguishing them from inline schemas

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Interactivity

- **INTR-02**: User can expand-all or collapse-all nodes with a single action
- **INTR-03**: User can hover over a node to see its description in a tooltip

### Rendering

- **REND-04**: String format annotations (email, date-time, uri) displayed on nodes

### Performance

- **PERF-01**: Large schemas (OpenAPI specs with 100+ definitions) render without noticeable lag

## Out of Scope

| Feature | Reason |
|---------|--------|
| Pan and zoom | Requires JS interop or complex SVG transforms, disproportionate risk for v1 |
| Schema editing/authoring | This is a viewer, not an editor |
| Schema validation | Display structure, don't validate data against it |
| Multi-file schema resolution | Single document input for v1 |
| Server-side processing | Client-only Elm app, no backend |
| Mobile-optimized layout | Desktop-first for diagram viewing |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Complete |
| FOUND-02 | Phase 1 | Complete |
| INPUT-01 | Phase 1 | Complete |
| INPUT-02 | Phase 1 | Complete |
| REND-01 | Phase 2 | Complete |
| REND-02 | Phase 2 | Complete |
| REND-03 | Phase 2 | Complete |
| INTR-01 | Phase 3 | Complete |
| VIS-01 | Phase 4 | Complete |
| VIS-02 | Phase 4 | Complete |

**Coverage:**
- v1.0 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-04-03*
*Last updated: 2026-04-03 after roadmap creation*
