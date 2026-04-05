# Phase 3: Expand/Collapse - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can click any container node (object, array, combinator) to collapse or expand its children, making large schemas navigable. $ref definitions expand inline when clicked, using the visited-set cycle guard from Phase 2. Leaf nodes (String, Integer, Number, Boolean, Null) are not interactive.

</domain>

<decisions>
## Implementation Decisions

### Collapse State Model
- **D-01:** Each node is identified by a schema path key (e.g., `root.properties.address.properties.street`). Path is built during rendering by appending property names and structural positions.
- **D-02:** Collapse state is stored as a `Set String` of collapsed path keys in the `Model`. Empty set = everything expanded.
- **D-03:** Collapse state resets to empty (fully expanded) on any schema re-parse — typing in textarea, selecting an example, or uploading a file. No attempt to preserve state across edits.

### $ref Inline Expansion
- **D-04:** Clicking a $ref node expands it inline — the referenced definition's full structure renders in-place as if it were written inline. Uses existing `Dict.get ref defs` lookup.
- **D-05:** When a circular $ref is detected during inline expansion (visited-set hit), display the existing cycle indicator pill (↺ symbol from Phase 2). The cycle pill is not clickable/expandable.
- **D-06:** Expanded $ref content looks identical to regular inline schema nodes — no visual wrapper or tint. The collapsed $ref pill (with `*` icon and definition name) already provides sufficient distinction.

### Default Expand Depth
- **D-07:** Schema renders fully expanded by default (current behavior preserved). The collapsed set starts empty. Users collapse nodes they don't need.

### Click Target & Feedback
- **D-08:** The entire pill-shaped node is the click target for expand/collapse. No separate +/- icon — clicking anywhere on a container node's pill toggles its children.
- **D-09:** Pointer cursor (`cursor: pointer`) on hover for container nodes only (Object, Array, OneOf/AnyOf/AllOf, $ref). No hover highlight or color change.
- **D-10:** Leaf nodes (String, Integer, Number, Boolean, Null) have no click handler and no pointer cursor.

### Claude's Discretion
- Path key separator and format details (e.g., dot-separated, bracket notation)
- How to thread the path accumulator through view functions alongside existing visited set and coordinates
- SVG click handler implementation (`Svg.Events.onClick` vs wrapping in clickable `g` element)
- Transition/animation on collapse (if any — not required)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project & Requirements
- `.planning/PROJECT.md` — Project vision, constraints (Elm 0.19.1, SVG only, client-only)
- `.planning/REQUIREMENTS.md` — INTR-01 is the requirement for this phase; REND-01 notes inline expansion deferred to Phase 3
- `.planning/ROADMAP.md` §Phase 3 — Success criteria (5 items)

### Prior Phase Context
- `.planning/phases/01-foundation-and-input/01-CONTEXT.md` — Phase 1 decisions (layout, live update, debounce)
- `.planning/phases/02-correct-rendering/02-CONTEXT.md` — Phase 2 decisions ($ref label rendering, visited-set cycle guard, dynamic viewBox, required/optional bold)

### Existing Code
- `src/Render/Svg.elm` — SVG renderer: `viewSchema` (main render dispatch, currently returns `Html msg` — needs upgrade to `Html Msg`), coordinate-threading pattern `(Svg msg, Dimensions)`, visited `Set String` already threaded through all view functions, `iconRect`/`roundRect` pill builders
- `src/Main.elm` — `Model` type (needs `collapsedNodes : Set String`), `Msg` type (needs `ToggleNode String`), `view`/`update` functions
- `src/Json/Schema.elm` — `Schema` union type, `ObjectProperty` (Required/Optional), `Definitions` dict

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `viewSchema` at `Render/Svg.elm:164` — main dispatch function, already pattern-matches all Schema variants and threads `Set String` (visited) through recursive calls
- `iconRect` / `roundRect` — pill-shaped node builders; these are the click targets that need `onClick` handlers
- `viewProperties` / `viewItems` — recursive renderers for object properties and array items; need path key threading
- Coordinate-threading pattern: `(Svg msg, Dimensions)` return type already established — adding path key and collapsed set is an extension of this pattern

### Established Patterns
- `Set String` threading: visited set is already threaded through `viewSchema -> viewProperties -> viewProperty -> viewSchema` chain — same pattern can carry collapsed set and current path
- `Msg` type in Main.elm already has multiple variants (TextareaChanged, TogglePanel, etc.) — adding ToggleNode follows existing pattern
- `view` function calls `Render.view defs schema` — signature needs to change to accept collapsed set and return `Html Msg` (concrete type)

### Integration Points
- `Render.Svg.view` signature: `Definitions -> Schema -> Html msg` needs to become `(String -> msg) -> Set String -> Definitions -> Schema -> Html msg` (or similar) to accept a message constructor and collapsed set
- `Main.update` needs a `ToggleNode String` case that toggles the path key in the collapsed set
- `Main.update` cases that re-parse the schema (TextareaChanged, ExampleSelected, FileContentLoaded) need to reset collapsed set to `Set.empty`

</code_context>

<specifics>
## Specific Ideas

- Inspiration from XMLSpy and similar tools: clicking a node toggles its children, tree stays in-place
- The path key approach mirrors JSON Pointer (RFC 6901) in spirit — each node has a unique structural address
- $ref expansion is effectively "substituting the definition inline" which is how JSON Schema $ref resolution works conceptually

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-expand-collapse*
*Context gathered: 2026-04-05*
