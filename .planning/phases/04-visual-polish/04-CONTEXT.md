# Phase 4: Visual Polish - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Add connector lines between parent and child nodes to communicate tree structure, and make $ref nodes visually distinguishable from inline schema nodes through a dashed border style. This completes the v1.0 visual experience.

</domain>

<decisions>
## Implementation Decisions

### Connector Line Style
- **D-01:** Curved bezier paths from parent to each child node. Smooth curves fan out from the parent's right edge to each child's left edge.
- **D-02:** Lines appear when a node is expanded and disappear when collapsed (integrates with Phase 3 expand/collapse state).

### Connector Line Color & Thickness
- **D-03:** Claude's discretion — pick a color and thickness that works with the existing dark theme (`darkClr` background, `lightClr` text/borders). Should complement without competing with node pills.

### Line Endpoints
- **D-04:** Lines exit from the right-center of the parent pill and enter at the left-center of each child pill. Standard left-to-right tree diagram convention.

### $ref Node Distinction
- **D-05:** $ref nodes use a dashed border (`strokeDasharray`) instead of the solid border used by inline schema nodes. Same pill shape, same background color, same `*` icon — only the border style changes.
- **D-06:** The existing ↺ cycle indicator pill (Phase 2) also gets the dashed border style, since it represents a circular $ref.

### Claude's Discretion
- Exact bezier curve control points for the connector paths
- Connector line color and thickness (D-03)
- `strokeDasharray` pattern for the dashed border (e.g., "4 2", "6 3")
- Whether connector lines should have rounded endpoints (`stroke-linecap: round`)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project & Requirements
- `.planning/PROJECT.md` — Project vision, constraints (Elm 0.19.1, SVG only, client-only)
- `.planning/REQUIREMENTS.md` — VIS-01, VIS-02 are the requirements for this phase
- `.planning/ROADMAP.md` §Phase 4 — Success criteria (3 items)

### Prior Phase Context
- `.planning/phases/01-foundation-and-input/01-CONTEXT.md` — Phase 1 decisions (layout, dark-themed pill nodes)
- `.planning/phases/02-correct-rendering/02-CONTEXT.md` — Phase 2 decisions ($ref label rendering with `IRef "*"` icon, ↺ cycle symbol, dynamic viewBox, required/optional bold)
- `.planning/phases/03-expand-collapse/03-CONTEXT.md` — Phase 3 decisions (collapse state as `Set String`, path key model, click targets, $ref inline expansion)

### Existing Code
- `src/Render/Svg.elm` — SVG renderer: coordinate-threading `(Svg msg, Dimensions)`, `iconRect` (pill builder with icon + separator + name), `IRef` icon type, `viewSchema`/`viewProperties`/`viewItems` recursive rendering, `darkClr`/`lightClr` color constants
- `src/Main.elm` — App entry point, wires `Render.Svg.view` with collapsed state

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `iconRect` at `Render/Svg.elm:509` — pill builder that creates rect + icon + separator + name. The rect element's `SvgA.stroke` is the border to change to dashed for $ref nodes.
- `separatorGraph` at `Render/Svg.elm:608` — draws a vertical line inside pills using `Svg.line` with `strokeLinecap "Round"`. Similar SVG line attributes needed for connector lines.
- `viewSchema` at `Render/Svg.elm` — main dispatch; returns coordinates and dimensions that can be used to calculate connector line start/end points.
- `darkClr` / `lightClr` — existing color constants for the dark theme.

### Established Patterns
- Coordinate-threading: every view function returns `(Svg msg, Dimensions)` — connector lines need the parent's position and each child's position to draw paths between them.
- `viewProperties` iterates over properties and accumulates y-offsets — this is where connector lines from object nodes to their children would be generated.
- `viewItems` handles array items — same pattern for array-to-item connectors.

### Integration Points
- Connector lines are generated inside `viewProperties`/`viewItems` (or a wrapper) since they need both parent and child coordinates.
- $ref dashed border is applied in `iconRect` when the icon is `IRef` — the existing `SvgA.stroke` on the rect element needs a conditional `SvgA.strokeDasharray`.
- Connector lines must respect the collapsed state — only draw lines to visible children.

</code_context>

<specifics>
## Specific Ideas

- Curved bezier paths (SVG `<path>` with cubic bezier `C` command) give a modern, clean look matching the user's preference
- Inspiration from tree visualization tools: smooth S-curves from parent right-center to child left-center
- Dashed border for $ref is a well-established UI convention meaning "reference" or "linked" — immediately readable without explanation

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-visual-polish*
*Context gathered: 2026-04-05*
