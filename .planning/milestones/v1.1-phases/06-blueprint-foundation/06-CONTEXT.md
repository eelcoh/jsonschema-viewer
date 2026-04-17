# Phase 6: Blueprint Foundation - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Transform the diagram panel from a white background to a dark navy blueprint aesthetic with a centralized Theme module for all color constants. The input panel and toolbar remain light. This phase establishes the visual foundation that Phase 7 (Node Design and Information Density) builds upon.

</domain>

<decisions>
## Implementation Decisions

### Background Style
- **D-01:** Dark navy background (~#1a2332) with a subtle dot grid pattern. The dots should be barely visible — subconscious texture, not prominent graph paper. Approximate: dot radius 0.5, spacing ~20px.
- **D-02:** Background and grid are both rendered as SVG elements — a full-bleed `<rect>` for the dark fill, and an SVG `<pattern>` with `<circle>` elements for the dot grid. Self-contained in the SVG output.
- **D-03:** CSS `.diagram-panel` background also set to `#1a2332` as a fallback to prevent white flash before SVG renders.

### Node Styling
- **D-04:** Switch from filled pills to outlined nodes — transparent/dark fill with light borders and white text. Classic blueprint look where nodes are shapes on the dark canvas, not colored blocks.
- **D-05:** $ref nodes retain dashed border distinction (solid outline for regular nodes, dashed outline for $ref). The solid-vs-dashed contrast works on any background color.

### Connector Lines
- **D-06:** Connector lines change to a muted blue-gray color (~#4a6a8a). Visible but doesn't compete with node borders — creates visual hierarchy.

### Theme Module
- **D-07:** Create `Render.Theme` module containing all color constants only. No spacing or sizing constants in this phase — keep the scope focused. Colors include: background, grid dot, node border, node fill, node text, connector, $ref border, error text.
- **D-08:** All color references in `Render/Svg.elm` (currently `darkClr`, `lightClr`, `color` helper) migrate to use `Render.Theme` constants.

### Input Panel & Toolbar
- **D-09:** Input panel and toolbar stay light (#f6f8fa). Clear visual separation between "editing" (light) and "viewing" (dark blueprint). No CSS changes to these areas.

### Error Display
- **D-10:** Error messages remain in the diagram panel area. Colors adapt for dark background — light text, adjusted heading and detail styling. Layout unchanged.

### Claude's Discretion
- Exact hex values for node border, text, grid dot, and connector colors (within the aesthetic: light/white borders+text, muted connectors, subtle grid)
- Grid pattern implementation details (SVG `<pattern>` sizing, patternUnits)
- Error display color specifics (as long as readable on dark background)
- Exact dot grid spacing and size (within the "subtle wallpaper" direction — ~20px, r~0.5)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project & Requirements
- `.planning/PROJECT.md` — Project vision, constraints (Elm 0.19.1, SVG only, client-only)
- `.planning/REQUIREMENTS.md` — VIS-01 is the requirement for this phase
- `.planning/ROADMAP.md` Phase 6 section — Success criteria (3 items)

### Prior Phase Context
- `.planning/phases/04-visual-polish/04-CONTEXT.md` — Phase 4 decisions (connector lines with cubic bezier, $ref dashed borders, darkClr/lightClr design)
- `.planning/phases/05-decoder-fixes/05-CONTEXT.md` — Phase 5 decisions (combined type+combinator rendering, BaseSchema pattern)

### Existing Code (critical for this phase)
- `src/Render/Svg.elm` — SVG renderer: `darkClr` (line 867, #3972CE), `lightClr` (line 863, #e6e6e6), `color` helper (line 858), `iconRect` (pill builder), `connectorPathD` (line 871), `view` (entry point that creates the `<svg>` element)
- `src/main.css` — `.diagram-panel` (line 136, currently `background: #ffffff`), `.error-container`/`.error-heading`/`.error-body`/`.error-detail` (lines 143-182, light-themed error styling)
- `src/Main.elm` — App entry point, wires `Render.Svg.view`, contains HTML structure with class names

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `color` helper at `Render/Svg.elm:858` — converts RGB to hex via `Color.Convert.colorToHex`. Can be reused or replaced in Theme module.
- `darkClr` / `lightClr` at `Render/Svg.elm:863-868` — current color constants to be replaced by Theme imports.
- `iconRect` at `Render/Svg.elm` — pill builder with `SvgA.fill` and `SvgA.stroke`. Fill changes to transparent, stroke stays as border color from Theme.
- `connectorPathD` at `Render/Svg.elm:871` — connector path generator. Color applied at call site, just needs Theme color swap.

### Established Patterns
- Coordinate-threading: every view function returns `(Svg msg, Dimensions)` — background rect and grid pattern are added at the top-level `view` function, not threaded through children.
- SVG attributes use string-based color values (`SvgA.fill`, `SvgA.stroke`) — Theme module exports strings directly.
- The `view` function in `Render/Svg.elm` creates the root `<svg>` element — this is where the background rect and grid pattern `<defs>` go.

### Integration Points
- `Render/Svg.elm` `view` function: add `<defs>` with grid pattern, add background `<rect>` and grid `<rect>` before diagram content
- `Render/Svg.elm` all color references: replace `darkClr`/`lightClr` with `Theme.*` imports
- `src/main.css` `.diagram-panel`: change `background: #ffffff` to `background: #1a2332`
- `src/main.css` `.error-*` classes: adapt text colors for dark background

</code_context>

<specifics>
## Specific Ideas

- The "subtle wallpaper" grid evokes engineering blueprints without being distracting — dots should blend into the background at normal viewing distance
- Outlined nodes on dark background is the classic blueprint/technical drawing aesthetic — think white ink on dark paper
- Muted blue-gray connectors create depth hierarchy: bright node borders (foreground), muted connectors (mid-ground), subtle grid (background)
- The light input panel / dark diagram split mirrors IDE patterns where the editor and preview have different themes

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-blueprint-foundation*
*Context gathered: 2026-04-11*
