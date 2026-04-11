# JSON Schema Viewer

## What This Is

An Elm 0.19.1 application that renders JSON Schema documents as interactive SVG diagrams. Users paste or upload a JSON Schema and explore it visually through expandable/collapsible diagram nodes with connector lines, type indicators, and distinct styling for `$ref` nodes.

## Core Value

Users can visually navigate and understand the structure of any JSON Schema document through an interactive SVG diagram with expandable/collapsible nodes.

## Current State

Shipped v1.0. Phase 5 (Decoder Fixes) complete — the app now supports modern JSON Schema:
- ~2,200 lines of Elm across 4 source files + tests
- 31 unit tests passing (including 7 decoder round-trip tests)
- Supports paste, file upload, and 4 example schemas (including TypeBox)
- Renders all JSON Schema draft-07 and 2020-12 constructs as SVG pill nodes
- `$defs` support with automatic `$ref` normalization to `#/definitions/` prefix
- Combined type+combinator schemas render both typed structure and combinator variants
- Interactive expand/collapse with `$ref` inline expansion and cycle detection
- Cubic bezier connector lines and dashed `$ref` borders

## Current Milestone: v1.1 Professional Visuals

**Goal:** Transform the diagram from a proof-of-concept look into a professional blueprint-style technical diagram with richer schema information and broader format support.

**Target features:**
- Blueprint/technical visual style — outlined nodes, type-based color coding, light background, structured connectors
- Refined node design — proper proportions, icon/label separation, consistent padding, rounded corners
- Better typography — font sizing hierarchy, monospace labels, readable descriptions
- Improved layout & spacing — consistent tree alignment, breathing room between nodes
- Information density — show descriptions, constraints (min/max, pattern), enum values, format annotations on nodes
- Decoder fixes — `$defs` support (JSON Schema 2020-12), handle combined type+combinator schemas

## Requirements

### Validated

- User can paste a JSON Schema into a textarea and see it rendered — v1.0
- User can upload a JSON Schema file and see it rendered — v1.0
- `$ref` nodes display definition names with distinct dashed-border styling — v1.0
- SVG viewport dynamically scales to fit the diagram — v1.0
- Required properties visually distinct from optional (bold vs normal weight) — v1.0
- Interactive expand/collapse of container nodes — v1.0
- Inline `$ref` expansion with cycle detection guard — v1.0
- Connector lines between parent and child nodes — v1.0
- Combinator schema visualization (oneOf/anyOf/allOf) — v1.0

### Active

- [ ] Expand-all / collapse-all with a single action
- [ ] Hover tooltips showing node descriptions
- [ ] String format annotations (email, date-time, uri) on nodes
- [ ] Large schema performance (100+ definitions)
- [x] `$defs` support (JSON Schema 2020-12) — Validated in Phase 5: Decoder Fixes
- [x] Combined type+combinator schemas (e.g. object+oneOf) — Validated in Phase 5: Decoder Fixes

### Out of Scope

- Server-side processing — client-only Elm app, no backend
- Schema editing/authoring — this is a viewer, not an editor
- Schema validation — display structure, don't validate data against it
- Multi-file schema resolution — single document input
- Pan and zoom — requires JS interop, disproportionate complexity
- Mobile-optimized layout — desktop-first for diagram viewing

## Constraints

- **Tech stack**: Elm 0.19.1 — pure functional, no JS interop for core logic
- **Rendering**: SVG only — no Canvas or HTML-based diagrams
- **Input**: Single JSON Schema document (no multi-file resolution)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Elm 0.19.1 | Existing codebase, type safety for schema modeling | Good |
| SVG rendering | Already implemented, vector-based scales well for diagrams | Good |
| Client-only | Simplicity, no server needed for schema visualization | Good |
| Coordinate-threading pattern | Each view function returns (Svg msg, Dimensions) for layout | Good — enables connector line math |
| Path-based collapse state | Set String with dot-separated paths for independent node identity | Good — handles duplicate property names at different depths |
| Visited-set cycle guard | Set of seen $ref strings prevents infinite recursion | Good — simple and effective |

## Evolution

This document evolves at phase transitions and milestone boundaries.

---
*Last updated: 2026-04-11 after Phase 5 (Decoder Fixes) completion*
