# Requirements: JSON Schema Viewer

**Defined:** 2026-04-09
**Core Value:** Users can visually navigate and understand the structure of any JSON Schema document through an interactive SVG diagram with expandable/collapsible nodes.

## v1.1 Requirements

Requirements for milestone v1.1 Professional Visuals. Each maps to roadmap phases.

### Decoder Fixes

- [ ] **DEC-01**: User can load JSON Schema 2020-12 documents using `$defs` and see definitions resolved correctly
- [ ] **DEC-02**: User can load schemas with combined type + combinator (e.g., `type: "object"` with `oneOf`) and see both the object properties and combinator variants rendered

### Visual Style

- [x] **VIS-01**: User sees the diagram rendered on a dark navy blueprint-style background with appropriate contrast for all text and nodes

### Node Design

- [x] **NODE-01**: User can distinguish required properties from optional ones via a clear visual marker (asterisk or badge), not just font weight
- [x] **NODE-02**: User can see string format annotations (email, date-time, uri, etc.) displayed as a badge on string nodes

### Information Density

- [x] **INFO-01**: User can see schema descriptions displayed as secondary text on nodes that have a `description` field
- [x] **INFO-02**: User can see constraints (min/max length, min/max value, pattern) displayed as compact notation on nodes
- [x] **INFO-03**: User can see enum values displayed on nodes that define allowed values

## Future Requirements

### Visual Enhancement

- Type-based color coding (per-type Okabe-Ito colorblind-safe palette)
- Type-colored connector lines (inherit parent node color)
- Collapse indicator with child count badge (e.g., "User {5}")

### Advanced Layout

- Expanded multi-line node cards with progressive disclosure

## Out of Scope

| Feature | Reason |
|---------|--------|
| Expanded node cards | High complexity — requires NodeLayout refactor across 9+ locations; defer to v1.2 |
| Dark mode toggle | Commit to blueprint aesthetic as the single theme |
| Animated transitions | High complexity via SVG animation in Elm; low value for technical tool |
| Drag-to-rearrange nodes | Requires physics engine; out of scope for read-only viewer |
| Multi-schema cross-referencing | Out of scope for single-document viewer |
| Tooltip/hover popups | SVG tooltips are janky; show info inline instead |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEC-01 | Phase 5 | Pending |
| DEC-02 | Phase 5 | Pending |
| VIS-01 | Phase 6 | Complete |
| NODE-01 | Phase 7 | Complete |
| NODE-02 | Phase 7 | Complete |
| INFO-01 | Phase 7 | Complete |
| INFO-02 | Phase 7 | Complete |
| INFO-03 | Phase 7 | Complete |

**Coverage:**
- v1.1 requirements: 8 total
- Mapped to phases: 8
- Unmapped: 0

---
*Requirements defined: 2026-04-09*
*Last updated: 2026-04-09 after v1.1 roadmap creation*
