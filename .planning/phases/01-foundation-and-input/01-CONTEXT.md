# Phase 1: Foundation and Input - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove build blockers (`Debug.log` calls) and upgrade from `Browser.sandbox` to `Browser.element` with user-controlled schema input (paste textarea + drag-and-drop file upload). Users can paste or upload their own JSON Schema and see it rendered as an SVG diagram.

</domain>

<decisions>
## Implementation Decisions

### Page Layout
- **D-01:** Side-by-side layout — textarea on the left, SVG diagram on the right
- **D-02:** Textarea is always visible but can be collapsed/closed by the user to maximize diagram space
- **D-03:** Diagram updates live as the user types in the textarea (no manual render button)

### Input Behavior
- **D-04:** File upload via drag-and-drop zone on the textarea area (no separate upload button)
- **D-05:** Drag-and-drop requires ports/JS interop — upgrade from `Browser.sandbox` to `Browser.element` enables this
- **D-06:** Remove hardcoded test schema strings from `Main.elm` — they become example schemas instead
- **D-07:** App starts with a pre-loaded example schema so users immediately see the diagram in action

### Error Presentation
- **D-08:** JSON/schema decode errors replace the diagram area (consistent with existing `errorToString` pattern)
- **D-09:** During live typing, keep showing the last successfully rendered diagram while input is invalid — only show errors after a brief pause (~1 second debounce or similar)

### Sample Schemas
- **D-10:** Provide a dropdown/button group with 2-3 example schemas (e.g., simple object, nested arrays, schema with $refs)
- **D-11:** Selecting an example replaces textarea content and triggers diagram re-render

### Claude's Discretion
- Debounce timing for live updates (exact delay)
- Specific example schemas to include (can draw from existing test data: person, arrays/veggie, or simplified versions)
- Visual styling of the collapse/expand control for the textarea panel
- Drag-and-drop visual feedback (hover state, accepted file types)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs — requirements fully captured in decisions above and in:

### Project & Requirements
- `.planning/PROJECT.md` — Project vision, constraints (Elm 0.19.1, SVG only, client-only)
- `.planning/REQUIREMENTS.md` — FOUND-01, FOUND-02, INPUT-01, INPUT-02 are the requirements for this phase
- `.planning/ROADMAP.md` §Phase 1 — Success criteria (4 items)

### Existing Code
- `src/Main.elm` — Current `Browser.sandbox` setup, hardcoded test schemas, `Model` type, `view` function
- `src/Render/Svg.elm` — Contains `Debug.log` calls that must be removed (lines 37, 667, 708, 710)
- `src/Json/Schema.elm` — Schema types, Definitions dict
- `src/Json/Schema/Decode.elm` — JSON decoder for schema

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Json.Schema.Decode.decoder` — Existing JSON Schema decoder, returns `Result Json.Decode.Error Json.Schema.Model`
- `Render.Svg.view` — Existing SVG renderer taking `Definitions -> Schema -> Html msg`
- `Model` type (`Result Json.Decode.Error Json.Schema.Model`) — Already handles decode success/failure

### Established Patterns
- Coordinate-threading pattern in SVG renderer: `(Svg msg, Dimensions)` return type
- Error display via `Json.Decode.errorToString` in `view` function
- Schema model split: `{ schema : Schema, definitions : Definitions }`

### Integration Points
- `main` needs upgrade from `Browser.sandbox` to `Browser.element` (adds subscriptions, Cmd support for ports)
- `Msg` type needs expansion beyond `NoOp` — needs messages for textarea input, file drops, example selection
- `init` changes from pure value to `(Model, Cmd Msg)` with flags
- Ports needed for drag-and-drop file reading (Elm can't read `FileReader` natively)

</code_context>

<specifics>
## Specific Ideas

- Inspiration from Altova XMLSpy and similar XML schema visualization tools (mentioned in PROJECT.md)
- The existing test schemas (person, arrays/veggie, Petstore swagger) are good candidates for the example dropdown — but may need simplification for the Petstore one
- Collapsible textarea panel similar to browser DevTools panels (drag to resize or click to collapse)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-and-input*
*Context gathered: 2026-04-03*
