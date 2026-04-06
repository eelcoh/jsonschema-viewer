# Phase 2: Correct Rendering - Context

**Gathered:** 2026-04-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix SVG rendering so all JSON Schema constructs display accurately: $ref nodes show definition names with distinct styling, the SVG viewport dynamically scales to fit the diagram, and required properties are visually distinguishable from optional ones. Circular $ref references are safely guarded against infinite recursion.

</domain>

<decisions>
## Implementation Decisions

### $ref Rendering
- **D-01:** $ref nodes render as labeled nodes showing the definition name with a distinct visual style (not inline expansion). The current `roundRect` label approach is kept but improved with the definition name.
- **D-02:** Inline expansion of $ref content is deferred to Phase 3 (expand/collapse). Phase 2 ensures the ref label is correct and visually distinct.
- **D-03:** Phase 2 success criterion #1 must be updated: "$ref nodes display the referenced definition name and are visually distinct" (replacing the original "renders fields inline" wording).

### Required vs Optional Distinction
- **D-04:** Required property names render in bold (`fontWeight "700"`), optional property names render in normal weight. This uses the existing bold pattern from `viewNameGraph`.
- **D-05:** No color or icon difference — bold/normal weight is sufficient distinction.

### Circular $ref Guard
- **D-06:** A visited-set pattern guards against infinite recursion when resolving $ref chains.
- **D-07:** When a circular $ref is detected, display the $ref node with its definition name plus a cycle indicator symbol (↺) to communicate the circular reference.

### SVG Viewport Sizing
- **D-08:** The SVG `viewBox` is calculated dynamically from the total diagram dimensions returned by the coordinate-threading pattern, plus padding.
- **D-09:** The SVG element uses `width`/`height` of 100% of its container. Small schemas fit tightly, large schemas expand to show everything.
- **D-10:** Replaces the current hardcoded `520x520` viewBox.

### Claude's Discretion
- Exact padding amount for the auto-fit viewBox
- Implementation details of the visited-set guard (Set vs Dict, threading approach)
- Specific ↺ symbol rendering (SVG text or Unicode character)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project & Requirements
- `.planning/PROJECT.md` — Project vision, constraints (Elm 0.19.1, SVG only, client-only)
- `.planning/REQUIREMENTS.md` — REND-01, REND-02, REND-03 are the requirements for this phase
- `.planning/ROADMAP.md` §Phase 2 — Success criteria (4 items, criterion #1 needs update per D-03)

### Prior Phase Context
- `.planning/phases/01-foundation-and-input/01-CONTEXT.md` — Phase 1 decisions (layout, input behavior, dark-themed pill nodes)

### Existing Code
- `src/Render/Svg.elm` — SVG renderer: `view` function (hardcoded 520x520 viewBox), `viewProperty` (no req/opt distinction), `viewSchema` Ref case (label-only rendering with commented-out expansion code), coordinate-threading pattern `(Svg msg, Dimensions)`
- `src/Json/Schema.elm` — `ObjectProperty` union type (`Required`/`Optional`), `Definitions` dict, `RefSchema` type with `ref` field
- `src/Json/Schema/Decode.elm` — JSON decoder; `$ref` keys stored with `#/definitions/` prefix
- `src/Main.elm` — App entry point, example schemas for testing

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `viewProperty` at `Render/Svg.elm:359` — already pattern-matches `Required` vs `Optional` to extract name, just needs different styling per variant
- `iconRect` with `IRef` icon type — existing ref node rendering, needs enhancement for definition name display
- `viewSchema` Ref case at `Render/Svg.elm:226` — has `Dict.get ref defs` lookup already, plus commented-out code showing expansion intent
- Coordinate-threading pattern: every view function returns `(Svg msg, Dimensions)` — the final dimensions can drive viewBox calculation

### Established Patterns
- Dark pill-shaped nodes with `darkClr` background and `lightClr` text (#e6e6e6 on blue)
- `fontWeight "700"` already used in `viewNameGraph` for property names — can differentiate required (bold) vs optional (normal weight)
- `roundRect` for simple labeled nodes, `iconRect` for type-indicating nodes with icon + separator + name

### Integration Points
- `view` function is the only entry point — needs to capture total dimensions from `viewSchema` and set viewBox dynamically
- `viewProperty` is where required/optional styling diverges
- `viewSchema` Ref branch is where circular guard and improved label rendering go
- Definitions dict is already threaded through all view functions

</code_context>

<specifics>
## Specific Ideas

- The ↺ symbol for circular refs communicates the concept universally without needing localization
- Bold vs normal weight for required/optional is the same convention used by many API documentation tools
- Auto-fit viewBox with padding follows the SVG best practice of computed viewBox from content dimensions
- Updating the success criterion for $ref keeps Phase 2 focused on correct labeling while Phase 3 handles the interactive expansion

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-correct-rendering*
*Context gathered: 2026-04-04*
