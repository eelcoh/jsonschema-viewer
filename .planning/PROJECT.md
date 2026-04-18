# JSON Schema Viewer

## What This Is

An Elm 0.19.1 application that renders JSON Schema documents as interactive SVG diagrams on a dark blueprint canvas. Users paste or upload a JSON Schema (including modern 2020-12 `$defs` and combined type+combinator shapes) and explore it visually through expandable/collapsible nodes with type/format/enum icons, required/optional border distinction, connector lines, and a hover overlay surfacing descriptions, constraints, and enum values.

## Core Value

Users can visually navigate and understand the structure of any JSON Schema document through an interactive SVG diagram with expandable/collapsible nodes and on-demand schema metadata.

## Current State

**Shipped v1.1 Professional Visuals (2026-04-17)** — the viewer now has a professional blueprint visual style with rich inline schema metadata and broader JSON Schema format support.

- ~2,486 lines of Elm across source + tests
- 46 unit tests passing (including 7 decoder round-trip tests and 15 icon/render tests)
- Supports paste, file upload, and example schemas (including TypeBox exercising `$defs` + combined type+oneOf)
- Renders JSON Schema draft-07 and 2020-12 constructs, including combined `type` + `oneOf`/`anyOf`/`allOf`
- `$defs` merged with `definitions`; `$ref` normalized at decode time
- Dark navy canvas (#1a2332) with dot-grid texture, outlined pill nodes, muted bezier connectors
- Centralized `Render.Theme` module owning all visual constants
- Required properties distinguished by amber (#e8a020) border in addition to bold font weight
- Format-as-type icons (email, date-time, hostname, ipv4, ipv6, uri, custom) with enum precedence per D-07
- Hover overlay (fixed-position HTML) surfaces description, constraints (min/max, length, pattern), and enum values for any node with metadata

**Known tech debt (from v1.1 audit):**
- Hardcoded color literals in Main.elm overlay instead of Theme.* references
- 7 orphaned Theme exports never consumed
- `Schema.Null` arm in `viewSchema` skips hover wiring — Null descriptions unreachable

## Requirements

### Validated

- ✓ User can paste a JSON Schema into a textarea and see it rendered — v1.0
- ✓ User can upload a JSON Schema file and see it rendered — v1.0
- ✓ `$ref` nodes display definition names with distinct dashed-border styling — v1.0
- ✓ SVG viewport dynamically scales to fit the diagram — v1.0
- ✓ Required properties visually distinct from optional (bold vs normal weight) — v1.0
- ✓ Interactive expand/collapse of container nodes — v1.0
- ✓ Inline `$ref` expansion with cycle detection guard — v1.0
- ✓ Connector lines between parent and child nodes — v1.0
- ✓ Combinator schema visualization (oneOf/anyOf/allOf) — v1.0
- ✓ `$defs` support (JSON Schema 2020-12) — v1.1 (DEC-01)
- ✓ Combined type+combinator schemas — v1.1 (DEC-02)
- ✓ Dark navy blueprint background with color-safe contrast — v1.1 (VIS-01)
- ✓ Required/optional visual marker beyond font weight (amber border) — v1.1 (NODE-01)
- ✓ String format annotations as type icon on nodes — v1.1 (NODE-02)
- ✓ Schema descriptions displayed on hover — v1.1 (INFO-01, partial for Schema.Null)
- ✓ Constraints (min/max, length, pattern) displayed on hover — v1.1 (INFO-02)
- ✓ Enum values displayed on hover — v1.1 (INFO-03)

### Active

Next milestone requirements will be defined via `/gsd:new-milestone`.

### Out of Scope

- Server-side processing — client-only Elm app, no backend
- Schema editing/authoring — this is a viewer, not an editor
- Schema validation — display structure, don't validate data against it
- Multi-file schema resolution — single document input
- Pan and zoom — requires JS interop, disproportionate complexity
- Mobile-optimized layout — desktop-first for diagram viewing
- Expanded multi-line node cards — high complexity, requires NodeLayout refactor across 9+ locations
- Dark mode toggle — committed to blueprint aesthetic as the single theme
- Animated transitions — high complexity via SVG animation in Elm; low value for technical tool
- Drag-to-rearrange nodes — requires physics engine; out of scope for read-only viewer
- Multi-schema cross-referencing — out of scope for single-document viewer

## Constraints

- **Tech stack**: Elm 0.19.1 — pure functional, no JS interop for core logic
- **Rendering**: SVG for the diagram; overlay is plain HTML positioned via mouse clientX/clientY
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
| Dict.union left-bias on $defs/definitions merge | `definitions` wins over `$defs` on key conflict, one canonical dict downstream | Good — decoder-layer normalization keeps renderer simple |
| `normalizeRef` at decode time | Rewrites `#/$defs/…` to `#/definitions/…` once, so rest of app sees a single prefix | Good — downstream code unaware of 2020-12 |
| Combinator field on BaseSchema | `Maybe (CombinatorKind, List Schema)` on every typed variant — uniform extraction | Good — supports `type: "object"` + `oneOf` etc. with one decoder path |
| Centralized `Render.Theme` module | Hex strings as SVG attributes, no Color type, no helper — single source of visual truth | Good — but not fully adopted (Main.elm overlay still uses literals) |
| `Render.Theme` strokeWidth 1 (from 0.2) | Outlined pill nodes on dark background need visible borders | Good — legible on dark navy |
| Required amber border via `borderColorForRequired` | Required status flows as explicit `Bool` through viewSchema, not derived from weight | Good — type-safe, pairs well with bold weight |
| `iconForSchema` pure dispatch with enum precedence | Enum presence overrides format per D-07; single function for all icon resolution | Good — kept simple by removing per-type view helpers |
| `ViewConfig` record threaded through views | Avoid adding 3 separate hover params to every recursive signature | Good — one record beats three pass-through params |
| Hover overlay as fixed-position HTML, not SVG | Earlier SVG overlay fell outside the dynamic viewBox | Good — deviation from plan worth capturing; mouse clientX/Y is reliable |
| `hasMetadata` guard before hover wiring | Skip mouseenter/leave on plain nodes to avoid spurious events | Good — only nodes that would show something are hoverable |

## Evolution

This document evolves at phase transitions and milestone boundaries.

---
*Last updated: 2026-04-17 after v1.1 Professional Visuals milestone shipped*
