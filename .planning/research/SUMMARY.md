# Project Research Summary

**Project:** JSON Schema Viewer — Interactive SVG Diagram
**Domain:** Browser-based schema visualization tool (Elm 0.19.1)
**Researched:** 2026-04-03
**Confidence:** HIGH

## Executive Summary

This is a working proof-of-concept Elm application that renders JSON Schema documents as SVG tree diagrams. The core rendering pipeline is sound — the coordinate-threading pattern (`(Svg msg, Dimensions)` return convention), the schema type model, and the draft-07 decoder are all in place. What it lacks is user-facing interactivity: schemas are hardcoded, the SVG viewport is clipped, `$ref` nodes do not expand, and there is no way to collapse large subtrees. The app functions as a demo, not a tool.

The recommended approach is to evolve the existing architecture incrementally rather than rewrite it. Only one new package is needed (`elm/file` for file upload). The largest architectural change is upgrading `Browser.sandbox` to `Browser.element` — a low-risk, isolated migration that unlocks everything else. After that, the work proceeds in a clear dependency order: clean up Debug calls, wire up user input, fix the SVG viewport, then add correctness features ($ref expansion), then interactivity (collapse/expand nodes), then visual polish (connector lines, required/optional distinction, format annotations).

The primary risks are well-understood and have clear mitigations. The three most important are: (1) `Debug.log` calls in `Render/Svg.elm` that block production builds and must be removed first; (2) circular `$ref` in real-world schemas that will cause infinite recursion if inline `$ref` expansion is implemented without a visited-set guard; and (3) non-unique property names that make expand/collapse state incorrect unless path-based node keys (not name-based keys) are used from the start. All three are preventable by doing the work in the right order with the right data structures.

## Key Findings

### Recommended Stack

The existing stack (elm/core, elm/browser, elm/html, elm/svg, elm/json, NoRedInk/elm-json-decode-pipeline, avh4/elm-color, noahzgordon/elm-color-extra, elm-community/list-extra) is complete and sufficient. The Elm 0.19.1 ecosystem is frozen and stable — no package versions will change. The only addition required is `elm/file 1.0.5` for the file upload feature. All other new capabilities (SVG click events via `Svg.Events`, textarea input via `elm/html`, expand/collapse state via `elm/core` Set) are already available in packages already present.

**Core technologies:**
- `elm/browser 1.0.2`: Application entry point — upgrade `Browser.sandbox` to `Browser.element` to unlock Cmd/Sub and user input
- `elm/svg 1.0.1`: SVG rendering and click events via `Svg.Events.onClick` — already present, no changes to package
- `elm/file 1.0.5`: File picker and file-as-string reading — the only new package needed (`elm install elm/file`)
- `elm/core 1.0.4`: `Set NodePath` for expand/collapse state, `Dict` for definitions lookup — already present
- `NoRedInk/elm-json-decode-pipeline 1.0.0`: Decoder ergonomics — no changes needed

### Expected Features

Reference tools (Altova XMLSpy, Liquid XML Studio, Oxygen XML Editor) establish clear conventions: nodes are individually collapsible, required vs optional fields are visually distinguished, type icons are on every node, connector lines show parent-child relationships, `$ref` targets resolve inline, and combinators (oneOf/anyOf/allOf) appear as distinct intermediate nodes.

**Must have (table stakes):**
- User can paste or upload their own JSON Schema — without this the app has zero utility for real users
- Dynamic SVG viewport — the hardcoded 520x520 clips every real-world schema
- Required vs optional property distinction — `ObjectProperty` is already decoded correctly but not rendered differently
- `$ref` nodes expand inline — a `$ref` that shows only a label is not a diagram
- All schema nodes render with type icons — Null branch currently bypasses the icon system
- Error display for invalid JSON — already basically working, minor polish only

**Should have (competitive differentiators):**
- Collapse/expand individual nodes — essential for navigating schemas with 20+ properties
- Connector lines between parent and child nodes — makes tree structure unambiguous
- Description tooltip via SVG `<title>` — `description` is decoded on every type but never shown
- Format annotation on string nodes — `StringFormat` is decoded but not rendered
- Distinct visual style for `$ref` nodes vs inline nodes — dashed border vs solid

**Defer to v2+:**
- Pan and zoom — requires JS interop or complex SVG transform handling
- Cardinality annotations on connectors — data is decoded; adds visual noise before diagram is otherwise clean
- Enum value display — needs design thought about layout overflow
- Search/filter within diagram — useful but second-order

### Architecture Approach

The three-layer module structure (`Json.Schema`, `Json.Schema.Decode`, `Render.Svg`) is the right shape and should be preserved. The key change to `Render.Svg` is threading two new parameters through all view functions: `expandState : Set NodePath` (read-only, checked at each expandable node) and `path : NodePath` (the address of the current node, accumulated as recursion descends). A new `Diagram.NodePath` module should be extracted to isolate path construction rules and make them testable. `Main.elm` gains a proper `Model` record holding raw input, parse result, and expand state.

**Major components:**
1. `Main.elm` — App shell, Model, Msg, update loop, input UI (textarea + file button); migrates to `Browser.element`
2. `Json.Schema` + `Json.Schema.Decode` — Type definitions and decoder; no changes needed
3. `Render.Svg` — SVG layout and rendering; significant changes for expand/collapse and `$ref` expansion
4. `Diagram.NodePath` (new) — Path construction, stable node identity, path-to-string serialization

### Critical Pitfalls

1. **Debug.log blocks production builds** — `elm make --optimize` rejects any `Debug.log` call with a hard compiler error. Three calls exist in `Render/Svg.elm` now. Remove them before touching anything else. This is a pre-condition for all other phases.

2. **Circular `$ref` causes infinite recursion** — Real-world OpenAPI specs contain self-referential definitions. Inline `$ref` expansion without a visited-set guard (`Set String` of currently-expanded ref keys) will stack-overflow the browser. Thread the visited set as a parameter in `viewSchema` and render a stub when a ref key is already in the set.

3. **Non-unique property names break expand/collapse** — Property names like `name`, `id`, `type` appear at multiple depths. Keying expand state by local name causes one toggle to affect all nodes with the same name. Use path-based keys (`List String` like `["properties", "address", "properties", "city"]`) from the start — retrofitting this is painful.

4. **Collapsed nodes must return correct dimensions** — The coordinate-threading pattern breaks if a collapsed node returns full-expanded dimensions for its children. Every collapsible branch must return only `pillHeight` when collapsed. The render path and the dimension return must be updated simultaneously.

5. **SVG click event bubbling** — Clicking a nested node fires both that node's handler and its parent's handler. Use `Html.Events.stopPropagationOn "click"` on every interactive node pill. Detect by testing two nested expandable objects.

## Implications for Roadmap

Based on the dependency graph in research and the critical pitfalls, a 5-phase structure is recommended. Each phase compiles and produces visible value independently.

### Phase 1: Foundation Cleanup and User Input
**Rationale:** Every subsequent feature depends on a clean build and user-controlled input. `Debug.log` removal is a hard prerequisite for optimized builds. `Browser.element` migration is a hard prerequisite for user input. These should be one phase because both are isolated, low-risk changes that reset the codebase to a clean starting point.
**Delivers:** App compiles cleanly under `--optimize`. Users can paste any JSON Schema (or upload a file) and see it rendered. Parse errors show a readable message.
**Addresses:** "User can paste own schema" (table stakes), "Error display" (table stakes)
**Avoids:** Pitfall 1 (Debug.log), Pitfall 5 (Browser.sandbox migration done in isolation)
**Stack additions:** `elm install elm/file`
**Files changed:** `Render/Svg.elm` (remove Debug), `Main.elm` (Browser.element, Model record, textarea, file input, SchemaInputChanged/FileRequested/FileSelected/FileLoaded msgs)

### Phase 2: Correct Rendering
**Rationale:** Before adding interactivity, the renderer should be correct for all schema types. This means fixing the clipped SVG viewport, making `$ref` nodes expand inline, and ensuring Null/required/optional/format annotations render properly. These are all non-interactive correctness fixes that make the app produce accurate diagrams.
**Delivers:** All JSON Schema constructs render correctly. Real-world schemas (Petstore Swagger) display without clipping. `$ref` definitions are visible inline. Required and optional properties look different.
**Addresses:** Dynamic SVG viewport (table stakes), `$ref` inline expansion (table stakes), Required/optional distinction (table stakes), All type icons including Null (table stakes), Format annotation on strings (differentiator)
**Avoids:** Pitfall 2 (circular `$ref` — add visited-set guard here), Pitfall 7 (fixed viewBox clips content)
**Files changed:** `Render/Svg.elm` ($ref expansion with Set String guard, dynamic viewBox, Null icon fix, viewProperty required/optional distinction, StringFormat render)

### Phase 3: Tree Interactivity (Expand/Collapse)
**Rationale:** This is the highest-value interactive feature. It depends on Phase 1 (Browser.element for Cmd support, Model record for state) and Phase 2 (correct rendering before hiding/showing subtrees). It requires the new `Diagram.NodePath` module and `ExpandState` in Model before touching the renderer.
**Delivers:** Users can collapse and expand any container node (Object, Array, OneOf/AnyOf/AllOf, Ref). Large schemas become navigable. Each toggled node correctly updates the layout.
**Addresses:** Collapse/expand nodes (differentiator — highest value)
**Avoids:** Pitfall 3 (path-based node keys — designed in from the start of this phase), Pitfall 4 (collapsed nodes return correct dimensions), Pitfall 6 (stopPropagationOn click), Pitfall 8 (recursive type alias — use `type` not `type alias` for any state tree)
**Files new/changed:** `Diagram/NodePath.elm` (new), `Main.elm` (ExpandState in Model, ToggleNode msg), `Render/Svg.elm` (thread expandState+path through all view fns, onClick handlers, conditional child rendering, collapse indicator)

### Phase 4: Visual Polish
**Rationale:** With correct rendering and interactivity stable, visual enhancements can be layered on without risk of destabilizing the layout engine. Connector lines require knowing child positions — available from the coordinate-threading return values already in place. Description tooltips and expand-all/collapse-all are independent additions.
**Delivers:** Connector lines between parent and child nodes. Description tooltips on hover (SVG `<title>`). Expand-all / Collapse-all controls. Distinct visual style for `$ref` nodes (dashed border).
**Addresses:** Connector lines (table stakes), Description tooltip (differentiator), Expand all/collapse all (differentiator), Distinct $ref visual style (differentiator)
**Avoids:** N/A — these are additive changes; no new pitfall categories introduced
**Files changed:** `Render/Svg.elm` (connector SVG lines in viewProperties/viewItems, `<title>` for description, dashed border on Ref nodes, collapse indicator icon)

### Phase 5: Performance and Large Schema Handling
**Rationale:** Performance tuning should come after correctness and interactivity are stable. `Svg.Lazy.lazy` is already imported in `Render/Svg.elm` but not used effectively. This phase addresses the performance cliff on schemas with 200+ nodes.
**Delivers:** Responsive interactions on large real-world OpenAPI specs. `Svg.Lazy.lazy` applied at node boundaries. Scrollable SVG container via CSS overflow.
**Addresses:** Large schema performance (deferred differentiator)
**Avoids:** Pitfall 9 (Dict performance cliff), Pitfall 13 (Svg.Lazy reference equality semantics)
**Files changed:** `Render/Svg.elm` (Svg.Lazy at Object/Array boundaries), `Main.elm` or CSS (scrollable wrapper div)

### Phase Ordering Rationale

- Phase 1 before everything: `Debug.log` and `Browser.sandbox` are hard blockers that corrupt subsequent work if left in place
- Phase 2 before Phase 3: Expand/collapse on incorrectly-rendered nodes is harder to verify; fix correctness first so interactivity testing has a clean baseline
- Phase 3 before Phase 4: Connector lines that appear/disappear on collapse must be tested against working collapse; connector lines added before collapse would need to be re-tested anyway
- Phase 5 last: Performance optimization is only meaningful once the feature set is complete; premature optimization with `Svg.Lazy` before expand/collapse is stable wastes effort

### Research Flags

Phases with standard patterns (skip `/gsd:research-phase`):
- **Phase 1:** Browser.element migration and textarea input are well-documented Elm patterns with no ambiguity
- **Phase 2:** Coordinate-threading and SVG rendering patterns are already in place; $ref guard is a standard tree-traversal pattern
- **Phase 4:** SVG `<title>` and line drawing are standard SVG; connector math is straightforward given existing Dimensions return values
- **Phase 5:** `Svg.Lazy` semantics are documented; the optimization approach is clear

Phases that may benefit from targeted research during planning:
- **Phase 3:** The `NodePath` design (List String vs String key) has subtle tradeoffs for `Set` performance and `Svg.Lazy` compatibility; a quick design validation before writing code is worthwhile

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Elm 0.19.1 is frozen; all packages verified against elm.json; only one new package needed |
| Features | MEDIUM | Reference tools (XMLSpy, Oxygen) are well-established; behavioral patterns are solid but not live-verified |
| Architecture | HIGH | Based on direct codebase analysis; patterns are derived from existing code, not speculation |
| Pitfalls | HIGH | All critical pitfalls derive from Elm language constraints and direct code analysis; not inferential |

**Overall confidence:** HIGH

### Gaps to Address

- **`$ref` decoder behavior with root-level `$ref`**: The decoder may not handle a schema whose top-level construct is `{ "$ref": "..." }` (Pitfall 12). Test this edge case in Phase 2 before implementing inline expansion. If it decodes to `Fallback`, the render produces a silent empty diagram.

- **Non-ASCII property name rendering**: `computeTextWidth` uses a fixed 7.2px-per-character approximation. For schemas with non-ASCII property names (common in international APIs), text will overflow pill containers. Acceptable for v1 but should be documented as a known limitation.

- **`oneOf`/`anyOf`/`allOf` sub-schema icons**: Current intermediate nodes use text-only labels (`"|1|"`, `"|o|"`, `"(&)"`). These are acceptable but visually weak. No clear reference design exists — this is a design decision to make during Phase 4.

## Sources

### Primary (HIGH confidence)
- Direct source analysis: `src/Render/Svg.elm`, `src/Json/Schema.elm`, `src/Json/Schema/Decode.elm`, `src/Main.elm`, `elm.json`
- Elm 0.19.1 Browser module API: https://package.elm-lang.org/packages/elm/browser/latest/Browser
- `elm/file` package: https://package.elm-lang.org/packages/elm/file/latest/
- `elm/svg` Svg.Events module: https://package.elm-lang.org/packages/elm/svg/latest/Svg-Events
- Elm Set (comparable keys including List String): https://package.elm-lang.org/packages/elm/core/latest/Set

### Secondary (MEDIUM confidence)
- Altova XMLSpy schema diagram view (XSD content model view) — behavioral patterns for node collapse, required/optional distinction, $ref inline display
- Liquid XML Studio Schema Browser — color-coding and cardinality annotation conventions
- Oxygen XML Editor JSON/XML schema diagram — combinator node visual treatment and pan/zoom patterns

---
*Research completed: 2026-04-03*
*Ready for roadmap: yes*
