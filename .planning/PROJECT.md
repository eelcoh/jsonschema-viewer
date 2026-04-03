# JSON Schema Viewer

## What This Is

An Elm 0.19.1 application that renders JSON Schema documents as interactive SVG diagrams, inspired by XML schema visualization tools like Altova XMLSpy, Liquid XML Studio, and Oxygen XML Editor. Users paste or upload a JSON Schema and explore it visually through expandable/collapsible diagram nodes.

## Core Value

Users can visually navigate and understand the structure of any JSON Schema document through an interactive SVG diagram with expandable/collapsible nodes.

## Current Milestone: v1.0 Interactive JSON Schema Viewer

**Goal:** Turn the proof-of-concept into a usable interactive SVG diagram viewer for JSON Schema documents.

**Target features:**
- User can paste/upload their own JSON Schema document
- Schema renders as a structured SVG diagram with type indicators, property names, and connector lines
- Nodes are expandable/collapsible for drilling into nested structures
- Handles real-world schemas with `$ref` resolution and combinator schemas (oneOf/anyOf/allOf)

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- Proof-of-concept SVG rendering of JSON Schema types (Object, Array, String, Integer, Number, Boolean, Null, Ref, OneOf/AnyOf/AllOf)
- JSON Schema draft-07 decoder using elm-json-decode-pipeline
- Type-indicating pill-shaped SVG nodes with icons ({..} for objects, [..] for arrays, S for strings)

### Active

<!-- Current scope. Building toward these. -->

- [ ] User can input their own JSON Schema (paste or upload)
- [ ] Interactive expand/collapse of schema nodes
- [ ] Proper `$ref` resolution and inline rendering
- [ ] Combinator schema visualization (oneOf/anyOf/allOf)
- [ ] Handles real-world schemas (e.g., OpenAPI component schemas)

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- Server-side processing — client-only Elm app, no backend
- Schema editing/authoring — this is a viewer, not an editor
- Schema validation — display structure, don't validate data against it
- Multi-file schema resolution — single document input for v1

## Context

- **Existing codebase:** Working Elm 0.19.1 proof-of-concept with hardcoded JSON Schema, decoder, and basic SVG renderer
- **Architecture:** `Browser.sandbox` with no user input — needs upgrade to `Browser.element` or `Browser.document`
- **SVG renderer:** Uses coordinate-threading pattern returning `(Svg msg, Dimensions)` — good foundation but non-interactive
- **Debug calls:** `Debug.log` in `Render.Svg` must be removed for production builds
- **Inspiration:** Altova XMLSpy diagram view, Liquid XML Studio Schema Browser, Oxygen XML Editor — all use tree-structured diagrams with expandable nodes, connector lines, type indicators, and cardinality annotations

## Constraints

- **Tech stack**: Elm 0.19.1 — pure functional, no JS interop for core logic
- **Rendering**: SVG only — no Canvas or HTML-based diagrams
- **Input**: Single JSON Schema document (no multi-file resolution)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Elm 0.19.1 | Existing codebase, type safety for schema modeling | -- Pending |
| SVG rendering | Already implemented, vector-based scales well for diagrams | -- Pending |
| Client-only | Simplicity, no server needed for schema visualization | -- Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check -- still the right priority?
3. Audit Out of Scope -- reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-03 after milestone v1.0 initialization*
