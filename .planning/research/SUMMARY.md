# Project Research Summary

**Project:** JSON Schema Viewer v1.1 — Professional Visuals
**Domain:** Elm 0.19.1 SVG Schema Visualization
**Researched:** 2026-04-09
**Confidence:** HIGH

## Executive Summary

This is a v1.1 visual upgrade of a working Elm SVG schema viewer. The existing codebase (1,806 lines across 4 modules) has clean architecture but hardcoded visual constants, no color differentiation between schema types, and no rendering of rich metadata that is already decoded in the model (descriptions, constraints, format, enum). The research confirms that zero new dependencies are needed — every required SVG capability (gradients, filters, markers, clip paths, embedded CSS) is already available in `elm/svg 1.0.1`, and the installed color packages (`avh4/elm-color`, `noahzgordon/elm-color-extra`) cover the entire palette management requirement.

The recommended approach is a staged visual overhaul: fix the two decoder gaps first (they are independent and unblock testing with modern schemas), then extract a `Render.Theme` module to centralize all style constants before touching any visual values, then apply blueprint aesthetic and type-based color coding, and finally add information density (description, constraints, format badges) after the layout coordinate system is stabilized. The single highest-risk task is multi-line variable-height nodes, which require a `NodeLayout`/`NodeMetrics` refactor touching every connector anchor point in the renderer.

The key risk is the `pillHeight = 28` constant, which is implicitly embedded in at least 9 code locations across `roundRect`, `iconRect`, `viewProperties`, `viewItems`, `viewNameGraph`, `separatorGraph`, `iconGeneric`, and `computeVerticalText`. Making any multi-line node changes without first extracting a `NodeLayout` record will produce silently misaligned connectors and overlapping nodes. All other risks are low: decoder fixes are isolated to two functions, and Theme extraction is a mechanical refactor with no behavior change.

## Key Findings

### Recommended Stack

No changes to `elm.json`. The existing stack is sufficient for every v1.1 goal. `elm/svg 1.0.1` exposes the full SVG 1.1 spec including `Svg.defs`, `Svg.linearGradient`, `Svg.filter`, `Svg.feGaussianBlur`, `Svg.feOffset`, `Svg.feMerge`, `Svg.clipPath`, `Svg.marker`, and `Svg.style`. Drop shadows, gradients, hover transitions, and type-based coloring are all achievable with what is installed.

Two new Elm modules should be created (`Render.Theme`, `Render.Node`) — these are code organization changes, not package additions. `elm-tree-diagram` and `typed-svg` were evaluated and rejected: both require significant migration effort with no capability gain over the existing coordinate-threading pattern.

**Core technologies:**
- `elm/svg 1.0.1`: SVG rendering — full SVG 1.1 spec, no gaps for v1.1 goals
- `avh4/elm-color` + `noahzgordon/elm-color-extra`: Color palette and hex conversion — already installed, handles all palette work
- `Render.Theme` (new module): Central visual config, type-to-color mapping using Okabe-Ito colorblind-safe palette
- `Render.Node` (new module): Measure-then-render split for variable-height pills
- `fontSize * 0.6` ratio: Font width approximation — reliable for ASCII monospace, no ports needed

### Expected Features

**Must have (table stakes):**
- Type-based color coding — every professional schema tool does this; current monochrome pills look prototypal
- Blueprint dark background (`#1a2332` range) — sets contrast requirements for all other colors
- Description display — already decoded on all schema types via `BaseSchema.description`; currently not rendered
- Constraint display — `minLength`/`maxLength`, `minimum`/`maximum`, `pattern`, `format` already in model
- Required vs optional visual distinction — bold weight alone is insufficient at small sizes; needs asterisk or badge
- `$defs` support — JSON Schema 2020-12 schemas from TypeBox, Zod, Ajv use `$defs`; currently silently broken

**Should have (differentiators):**
- Type-colored connector lines — trivial once color palette exists; no other schema tool does this
- Format badges — `StringFormat` already decoded; low effort, high semantic value
- Collapse indicator with child count badge — low effort, high information scent
- Enum value display — already decoded; needs compact `{val1|val2}` notation

**Defer (v2+):**
- Expanded node cards (full progressive disclosure) — highest complexity; may surface unexpected coordinate-threading issues
- Multi-schema cross-referencing — out of scope for single-document viewer
- Animated transitions — technical users prefer speed; SVG animation in Elm requires ports or animation frames

### Architecture Approach

The codebase follows a clean three-layer architecture: `Json.Schema` (pure types), `Json.Schema.Decode` (JSON to model), `Render.Svg` (model to SVG). The coordinate-threading pattern — where every render function returns `(Svg msg, Dimensions)` — is well-suited to the domain and should be kept. The main architectural change for v1.1 is extracting style constants into `Render.Theme` and splitting single-node rendering into `Render.Node` with a measure-before-render contract.

**Major components:**
1. `Json.Schema` + `Json.Schema.Decode` — Add `$defs` decoder support and optional `ObjectWithCombinator` variant; otherwise unchanged
2. `Render.Theme` (NEW) — `Theme` record with all visual constants; `default` blueprint value; `nodeColor : Theme -> Icon -> String` mapping
3. `Render.Node` (NEW) — `NodeContent`, `NodeMetrics`, `nodeContentFromSchema`, `measure`, `render`; provides accurate `anchorY` for connector attachment
4. `Render.Svg` (MODIFIED) — Thread `Theme`/`RenderContext`, delegate pill rendering to `Render.Node`, keep coordinate-threading for tree layout

### Critical Pitfalls

1. **Variable-height nodes break coordinate-threading** — `pillHeight = 28` is embedded in 9+ locations; extract `NodeLayout` record with `height`, `centerY`, `textBaselineY`, `connectorY` before any multi-line work; changing height in one place without updating all breaks connectors silently with no runtime error

2. **Decoder oneOf ordering regression** — `objectDecoder` matches `{"type": "object"}` before combined object+combinator decoders; add `objectWithOneOfDecoder`/`objectWithAnyOfDecoder`/`objectWithAllOfDecoder` BEFORE plain `objectDecoder`; combined decoders must precede their components

3. **`extractRefName` hardcodes prefix length** — `String.dropLeft 14` is correct for `#/definitions/` (14 chars) but produces `efs/Foo"` for `#/$defs/` (8 chars); replace with `startsWith` guards for both prefixes

4. **Color system without central Theme becomes unmaintainable** — `darkClr` and `lightClr` are referenced in 6+ functions; per-type colors added by branching inside render functions creates scattered logic; extract `Render.Theme` first, touch colors only through it

5. **Blueprint background requires full color audit** — `#3972CE` fill and `#e6e6e6` text were designed for a light background; on dark navy (`#1a2332`) all existing colors need WCAG AA contrast verification (4.5:1 for text, 3:1 for UI) before any new colors are added

## Implications for Roadmap

The dependency graph from combined research dictates a 4-phase structure. Decoder fixes are independent of rendering. Theme extraction is prerequisite for all visual work. NodeLayout refactor is prerequisite for multi-line content. Information density features come last after layout is stable.

### Phase 1: Decoder Fixes

**Rationale:** Independent of all rendering changes; isolated to two functions (`definitionsDecoder`, `extractRefName`) with very low risk; unblocks testing with real-world modern schemas (TypeBox, Zod output) before visual work begins

**Delivers:** Correct rendering for JSON Schema 2020-12 schemas using `$defs`; foundation for optional `ObjectWithCombinator` variant

**Addresses:** `$defs` support, combined type+combinator handling

**Avoids:** Pitfall 3 (decoder ordering regression), Pitfall 4 (`extractRefName` prefix bug)

### Phase 2: Theme Extraction and Blueprint Foundation

**Rationale:** `Render.Theme` extraction is prerequisite for every visual change — it centralizes 9+ hardcoded style constants so subsequent phases modify values in one place; blueprint background must come before color-dependent features because it sets contrast requirements; the Theme extraction step has zero behavior change risk (pixel-identical output until values change)

**Delivers:** `Render.Theme` module, `RenderContext` grouping reducing `viewSchema` parameter count, blueprint dark background (`#1a2332`), type-based color coding (Okabe-Ito palette), type-colored connector lines, `FontWeight` union type replacing string `"700"`/`"400"`

**Uses:** `avh4/elm-color` and `noahzgordon/elm-color-extra` for hex conversion and color derivation

**Avoids:** Pitfall 6 (unmaintainable color system), Pitfall 15 (contrast audit gap), Pitfall 10 (string-based font weight)

### Phase 3: NodeLayout Refactor and Information Density

**Rationale:** NodeLayout refactor (extracting `NodeLayout`/`NodeMetrics` record, replacing all `y + 14` connector anchors with `anchorY`) must precede multi-line content because variable-height nodes break the coordinate contract; once layout is correct, description/constraint/format/enum features are additive and low-risk

**Delivers:** `Render.Node` module with `measure`/`render` split, `anchorY`-based connector attachment, description text rendering, constraint display (`[min..max]` compact notation), format badges, enum values, required/optional asterisk badge, collapse indicator with child count

**Implements:** `Render.Node` architecture component

**Avoids:** Pitfall 1 (variable-height coordinate contract), Pitfall 7 (connector anchor misalignment), Pitfall 2 (text width per font size), Pitfall 5 (SVG text wrapping via tspan), Pitfall 9 (title field ignored), Pitfall 11 (Coordinates/Dimensions type alias confusion), Pitfall 13 (unbounded enum width), Pitfall 14 (SVG character escaping)

### Phase 4: Schema Type Extension (Optional v1.1 stretch / v1.2)

**Rationale:** Adding `ObjectWithCombinator` schema variant is medium risk (requires updating all exhaustive pattern matches in `viewSchema` and `getName`); defer until after visual polish is settled so testing scope is bounded; may slide to v1.2 if Phase 3 surfaces unexpected layout complexity

**Delivers:** Correct rendering for OpenAPI-style schemas combining `type: "object"` with `oneOf`/`anyOf`/`allOf`

**Avoids:** Pitfall 8 (Fallback wildcard hiding missing cases — temporarily remove Fallback to force exhaustive compile errors before adding variant)

### Phase Ordering Rationale

- Phase 1 before Phase 2: Decoder fixes have no dependencies and provide immediate testing value; real-world schemas (TypeBox, Zod) can be tested against visual changes in Phase 2
- Phase 2 before Phase 3: `Render.Theme` is required input to `Render.Node` (measure needs font size and padding constants from Theme); color and spacing must be settled before multi-line layout math is locked in
- Phase 3 deferred until Phase 2 complete: Every layout change in Phase 3 touches the coordinate-threading contract; doing this before spacing constants are settled means redoing layout math when values change
- Phase 4 last: New Schema variant requires exhaustive pattern match updates; lower risk to do this after all other changes are committed and visually tested

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (NodeLayout refactor):** The 9+ hardcoded `y + 14` and `y + 28` sites need a complete inventory before planning; use `grep -n "y + 14\|+ 28\|28 +" src/Render/Svg.elm` to enumerate all change sites
- **Phase 3 (text width validation):** The `fontSize * 0.6` monospace ratio needs visual validation against actual font rendering before finalizing node width calculations; plan an explicit test render step in the phase plan

Phases with standard patterns (skip research-phase):
- **Phase 1 (decoder fixes):** Both changes are straightforward; complete code snippets are in ARCHITECTURE.md and STACK.md, ready to implement directly
- **Phase 2 (Theme extraction):** Mechanical Elm record-threading refactor; established pattern in the ecosystem; no research needed

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified via elm/svg source on GitHub; all referenced elements confirmed present in 1.0.1; package capabilities verified against Elm package registry |
| Features | HIGH | Based on direct source code inspection of all decoded model fields; industry conventions from Redoc/Swagger/Stoplight well-documented; specific hex values MEDIUM pending visual testing |
| Architecture | HIGH | Based on reading actual implementation (not prior proposals); all integration points derived from real codebase state; 9-site inventory of `pillHeight` usage is line-specific |
| Pitfalls | HIGH | All critical pitfalls grounded in specific line-number references from source code reading; no speculative pitfalls included |

**Overall confidence:** HIGH

### Gaps to Address

- **Specific pixel values for spacing:** `childIndent` (recommended 20-24px), `siblingGap` (recommended 12-14px), `nodeHPadding` need visual iteration during Phase 2; plan an explicit tune-spacing step after blueprint background is applied
- **Color contrast verification:** All 9 Okabe-Ito palette colors need WCAG AA contrast check against `#1a2332` during Phase 2; `#009E73` (String green) may need lightening to `#00C896`
- **Phase 4 scope decision:** Whether `ObjectWithCombinator` is in v1.1 or v1.2 should be decided at Phase 3 completion based on actual complexity; the decoder portion (Phase 1) is always worth doing regardless

## Sources

### Primary (HIGH confidence)
- `src/Render/Svg.elm` (lines 28-512) — direct source inspection for all coordinate-threading details and pitfall locations
- `src/Json/Schema/Decode.elm` — direct source inspection for oneOf order and extractRefName hardcoding
- `src/Json/Schema.elm` — direct source inspection for type aliases and Fallback variant
- [elm/svg source](https://github.com/elm/svg/blob/master/src/Svg.elm) — full element list confirming all SVG 1.1 capabilities available
- [JSON Schema 2020-12 spec](https://json-schema.org/draft/2020-12/json-schema-core#section-8.2.4) — $defs keyword definition
- [Okabe-Ito palette](https://easystats.github.io/see/reference/scale_color_okabeito.html) — peer-reviewed colorblind-safe categorical palette hex values
- [WCAG 2.1 contrast requirements](https://www.w3.org/TR/WCAG21/#contrast-minimum) — 4.5:1 for text, 3:1 for UI components

### Secondary (MEDIUM confidence)
- [TypeBox output format](https://github.com/sinclairzx81/typebox) — produces 2020-12 schemas with $defs
- [Redoc theme source](https://github.com/Redocly/redoc/blob/main/src/theme.ts) — schema rendering reference for constraint display patterns
- [Swagger UI required field indicators](https://github.com/swagger-api/swagger-ui/issues/3255) — required field convention research
- Specific hex values for Okabe-Ito palette — will need visual testing against dark background before finalizing

### Tertiary (LOW confidence)
- Node sizing pixel values (20-24px childIndent, 12-14px siblingGap) — derived from general spacing principles; require visual iteration during Phase 2

---
*Research completed: 2026-04-09*
*Ready for roadmap: yes*
