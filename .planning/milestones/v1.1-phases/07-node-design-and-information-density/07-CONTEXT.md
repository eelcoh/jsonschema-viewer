# Phase 7: Node Design and Information Density - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can distinguish required from optional properties at a glance and read schema metadata (descriptions, constraints, formats, enums) directly on diagram nodes via hover overlays. The pill shape stays minimal — metadata is revealed on demand, not cluttered onto the node.

</domain>

<decisions>
## Implementation Decisions

### Required Property Marker
- **D-01:** Required properties have an amber/warm-colored border instead of the default #a0c4e8. Optional properties keep the default border color. This is a purely color-based distinction — no asterisk, dot, or badge.
- **D-02:** Required properties also keep bold font weight (from Phase 2). Double signal: amber border + bold text for required, default border + normal weight for optional.
- **D-03:** Add `requiredBorder` color constant to `Render.Theme`.

### Format as Type
- **D-04:** Well-known string formats (Email, DateTime, Hostname, Ipv4, Ipv6, Uri) replace the 'S' icon in the type position with a distinct icon. The node reads as `[email-icon | user_email]` not `[S | user_email]`.
- **D-05:** Custom string formats (the `Custom String` variant) show the format name as text in the icon position, replacing 'S'. E.g., `[phone | contact_number]`.
- **D-06:** Strings without a format keep the existing 'S' icon unchanged.

### Enum as Type
- **D-07:** When a node has `enum` values, the type icon is replaced with an 'Enum' icon/text regardless of base type (string, integer, etc.). The base type is visible in the hover overlay.
- **D-08:** The actual enum values are shown in the hover overlay, not on the pill.

### Hover Overlay for Metadata
- **D-09:** All nodes that have metadata (description, constraints, enum values, format details) show a custom SVG overlay panel on mouse hover. The overlay appears near the node without shifting the diagram layout.
- **D-10:** The overlay is implemented as SVG elements rendered by Elm using `Svg.Events.onMouseOver` / `Svg.Events.onMouseOut` — not browser-native `<title>` tooltips. This is a custom Elm-rendered panel, not the "janky SVG tooltips" excluded in REQUIREMENTS.md.
- **D-11:** Hover overlays appear on ALL node types that have metadata — leaf nodes (String, Integer, Number, Boolean, Null) and container nodes (Object, Array) alike.
- **D-12:** Descriptions show in full (not truncated) in the overlay.

### Constraint Display
- **D-13:** Constraints (minLength, maxLength, minimum, maximum, pattern) appear only in the hover overlay. No visual hint on the pill itself.

### Pill Design
- **D-14:** The pill shape and overall node design stays minimal. No inline badges, suffixes, or sub-lines added to the pill. The pill shows: type icon (or format icon / enum icon) + property name. All extra info is in the overlay.

### Claude's Discretion
- Exact amber/warm color hex for required border (should contrast with default #a0c4e8 on dark background)
- Icon designs for well-known string formats (could be unicode symbols, short text abbreviations, or SVG glyphs)
- Hover overlay positioning, sizing, background color, and text layout
- Hover overlay z-ordering (must render on top of other nodes)
- How to manage hover state in the Elm Model (which node is hovered, if any)
- NodeLayout refactoring approach for variable pill widths (format/enum icons may be wider than single-char icons)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project & Requirements
- `.planning/PROJECT.md` — Project vision, constraints (Elm 0.19.1, SVG only, client-only)
- `.planning/REQUIREMENTS.md` — NODE-01, NODE-02, INFO-01, INFO-02, INFO-03 are the requirements for this phase
- `.planning/ROADMAP.md` Phase 7 section — Success criteria (5 items)

### Prior Phase Context
- `.planning/phases/04-visual-polish/04-CONTEXT.md` — Phase 4 decisions (connector lines, $ref dashed borders)
- `.planning/phases/05-decoder-fixes/05-CONTEXT.md` — Phase 5 decisions (combined type+combinator, BaseSchema pattern with combinator field)
- `.planning/phases/06-blueprint-foundation/06-CONTEXT.md` — Phase 6 decisions (dark background, outlined nodes, Render.Theme module)

### Existing Code (critical for this phase)
- `src/Json/Schema.elm` — Schema union type with all metadata fields: `StringSchema` (format, minLength, maxLength, pattern, enum), `IntegerSchema`/`NumberSchema` (minimum, maximum, enum), `BooleanSchema` (enum), `BaseSchema` (title, description), `StringFormat` type (DateTime, Email, Hostname, Ipv4, Ipv6, Uri, Custom)
- `src/Json/Schema/Decode.elm` — Decoder already parses all metadata fields (description, format, minLength, maxLength, pattern, minimum, maximum, enum). `stringFormat` function at line 180 maps format strings to `StringFormat` variants.
- `src/Render/Svg.elm` — SVG renderer: `pillHeight = 28` (line 31, hardcoded in 9+ locations), `iconRect` (pill builder with icon + separator + name), `viewSchema`/`viewProperties`/`viewItems` recursive rendering, coordinate-threading `(Svg msg, Dimensions)` pattern, `fontSize "12"` used everywhere
- `src/Render/Theme.elm` — Centralized color constants: `nodeBorder` (#a0c4e8), `nodeText` (#e8f0f8), `nodeFill` (transparent), `connector` (#4a6a8a), `background` (#1a2332)
- `src/Main.elm` — App entry point, Model with `collapsedNodes : Set String`, wires `Render.Svg.view`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `iconRect` in `Render/Svg.elm` — pill builder that accepts an Icon type and name. The Icon type (`IObj`, `IArr`, `IStr`, `IInt`, `INum`, `IBool`, `INull`, `IRef`) needs extension for format icons and Enum.
- `Render.Theme` module — add `requiredBorder` color constant here for amber required borders.
- `StringFormat` type in `Json/Schema.elm` — already decoded, ready for icon dispatch in renderer.
- `ObjectProperty` union type (Required/Optional) — already threaded through `viewProperties`/`viewProperty`, provides the required/optional distinction for border color selection.

### Established Patterns
- Coordinate-threading: every view function returns `(Svg msg, Dimensions)` — hover overlay is rendered separately (not part of coordinate-threaded layout) since it doesn't shift other nodes.
- `Set String` for collapse state — similar pattern could track hover state (single `Maybe String` for hovered node path).
- `Render.Theme` for all colors — new colors (requiredBorder, overlay background) go here.

### Integration Points
- `iconRect` needs to accept format/enum icon variants and conditionally apply required vs default border color.
- `Main.elm` Model needs hover state (`hoveredNode : Maybe String` or similar).
- `Render.Svg.view` signature may need a hover message constructor alongside the existing toggle message.
- Overlay SVG elements should render last (after all nodes) to ensure they appear on top of the diagram.

</code_context>

<specifics>
## Specific Ideas

- Format-as-type follows the user's mental model: an email field IS an email, not "a string that happens to be formatted as email"
- Enum-as-type similarly: a status field with fixed values IS an enum, the base type is an implementation detail
- The hover overlay approach keeps the diagram scannable at a glance while making all detail accessible — similar to how IDE tooltips work
- The overlay must render on top of other nodes — SVG render order determines z-index, so overlay elements go last in the SVG tree

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-node-design-and-information-density*
*Context gathered: 2026-04-12*
