# Domain Pitfalls

**Domain:** Elm 0.19.1 SVG JSON Schema Viewer - v1.1 Visual Polish
**Researched:** 2026-04-09 (updated from 2026-04-07)

## Critical Pitfalls

Mistakes that cause rewrites or major issues.

### Pitfall 1: Variable-Height Nodes Break the Coordinate-Threading Contract

**What goes wrong:** The current renderer returns `(Svg msg, Dimensions)` where `Dimensions = (Float, Float)` represents the bottom-right corner of the rendered element (`(rightX, bottomY)`). Every parent uses this to position the next sibling. When nodes become variable-height (multi-line descriptions, constraints, enums), the `y + 28` assumption baked into every dimension calculation breaks silently — nodes overlap or leave gaps.

**Why it happens:** The constant `pillHeight = 28` is not just used in `roundRect` and `iconRect` — it is implicitly threaded through `computeTextHeight` (hardcoded to 28), `computeVerticalText` (which adds 15 for centering in a 28px box), the `y + 14` connector anchor point calculations in `viewProperties` and `viewItems`, and the `+ 10` vertical spacing between siblings. Changing pill height in one place without updating all these dependent calculations creates misalignment.

**Concrete locations in code:**
- `roundRect`: `SvgA.height "28"` inline string, `( rectWidth + x, 28 + y )` dimension return
- `iconRect`: `SvgA.height "28"` inline string, `( rectWidth + x, 28 + y )` dimension return
- `computeTextHeight`: returns literal `28`, not referenced from `pillHeight`
- `computeVerticalText`: returns `y + 15` (which assumes 28px height for centering)
- `viewNameGraph`: `dims = ( x + fullWidth, y + 28 )` hardcodes 28
- `separatorGraph`: `dims = ( x + strokeWidth, y + 28 )` hardcodes 28
- `iconGeneric`: `dims = ( x + strWidth, y + strHeight )` where `strHeight = computeTextHeight = 28`
- `viewProperties` inner loop: `connector` anchors at `y + 14` (half of 28)
- `viewItems` inner loop: `connector` anchors at `y + 14` (half of 28)

**Consequences:** Connector lines attach to wrong positions. Child nodes overlap parent nodes. Sibling nodes overlap each other. These bugs are visual-only (no runtime errors), making them hard to catch without visual regression testing.

**Prevention:**
1. Extract a `NodeLayout` record type that computes all derived values from a single height source:
   ```elm
   type alias NodeLayout =
       { height : Float
       , centerY : Float      -- height / 2, replaces hardcoded 14
       , textBaselineY : Float -- replaces computeVerticalText's y + 15
       , connectorY : Float   -- y + centerY, replaces y + 14
       }
   ```
2. Make `iconRect` and `roundRect` accept or compute a `NodeLayout` and return it alongside dimensions.
3. Replace all bare `y + 14`, `y + 15`, `y + 28` with layout-derived values in a single pass.
4. Add test cases for `viewSchema` that verify returned dimensions for multi-line nodes.

**Detection:** Visual inspection of schemas with descriptions (the Person example has descriptions on every field). If connector lines don't meet pill midpoints, the coordinate contract is broken.

**Phase:** Must be addressed before any multi-line content work.

---

### Pitfall 2: Text Width Approximation Catastrophically Wrong for Mixed Font Sizes

**What goes wrong:** The current `computeTextWidth` uses `String.length text * 7.2`, which assumes monospace 12px font. When v1.1 introduces typography hierarchy (different sizes for property names, types, descriptions, constraint values), this single multiplier produces wildly incorrect widths. Pill backgrounds will be too narrow (text overflows) or too wide (wasted space), and child positioning based on `rightX` will be wrong.

**Why it happens:** SVG has no built-in text measurement from Elm. The browser's `getComputedTextLength()` API is available in JavaScript but requires ports in Elm 0.19, which adds async complexity (measure, then render). The 7.2 constant is only valid for one specific font-size/font-family combination.

**Concrete location:** `computeTextWidth txt = String.length txt |> Basics.toFloat |> (*) 7.2` — used by `roundRect` (for full text), `iconGeneric` (for icon labels), and `viewNameGraph` (for property names). The `rectWidth = textWidth + 30` calculation in `roundRect` and the `fullWidth = computeTextWidth name` in `viewNameGraph` both cascade errors from this.

**Consequences:** Text overflows pill boundaries. Nodes positioned based on wrong parent width overlap or leave large gaps. The problem compounds: each node's error shifts all subsequent siblings.

**Prevention:**
1. Build a width lookup per font configuration rather than using a single constant:
   ```elm
   charWidthForSize : Float -> Float
   charWidthForSize fontSize =
       fontSize * 0.6  -- monospace ratio, adjust per font
   
   textWidth : Float -> String -> Float
   textWidth fontSize text =
       String.length text |> toFloat |> (*) (charWidthForSize fontSize)
   ```
2. Keep ALL text in monospace for v1.1 to avoid proportional font width uncertainty. Use font size and weight as the only typographic variables.
3. If proportional fonts are needed later, use ports with `getComputedTextLength()` via a two-pass render: measure invisible text first, then render with known widths.

**Detection:** Load a schema with long property names (20+ characters) and short ones (1-3 characters) side by side. If pill widths don't match text content, the approximation is wrong.

**Phase:** Address when introducing typographic hierarchy (description text, constraint text at smaller font sizes).

---

### Pitfall 3: Decoder oneOf Order Regression When Adding Combined Schemas

**What goes wrong:** The current decoder uses `oneOf` with Object first. When adding support for `type: "object"` + `oneOf` (a common JSON Schema pattern where an object has both properties AND a oneOf/anyOf combinator), the decoder must handle this combined case. If inserted at the wrong position in the `oneOf` chain, it either shadows existing decoders (eating all objects) or is never reached (shadowed by the plain Object decoder).

**Why it happens:** Elm's `Json.Decode.oneOf` tries decoders sequentially and returns the first success. The current Object decoder succeeds for ANY JSON with `"type": "object"` — it does not check for absence of `oneOf`/`anyOf`/`allOf`. So a schema with `{"type": "object", "properties": {...}, "oneOf": [...]}` will decode as a plain Object, silently dropping the combinator.

**Concrete location in code:** `schemaDecoder` uses `oneOf` starting with the Object decoder at line 37. The Object decoder's `withType "object"` guard succeeds whenever `"type": "object"` is present, regardless of other fields. The combinator decoders (OneOf, AnyOf, AllOf) come last and use `required "oneOf"` which would also match — but the Object decoder wins first.

**Consequences:** Combined schemas lose their combinator branches. Users see an object node with properties but no oneOf/anyOf variants. This is a silent data loss bug — no decoder error, just missing information.

**Prevention:**
1. Add the combined object+combinator decoder BEFORE the plain Object decoder in the `oneOf` chain:
   ```elm
   oneOf
       [ -- Combined schemas first (more specific)
         objectWithOneOfDecoder
       , objectWithAnyOfDecoder
       , objectWithAllOfDecoder
       -- Then plain schemas
       , objectDecoder
       , arrayDecoder
       , ...
       ]
   ```
2. Alternatively, restructure: decode Object, then check for combinator fields and attach them. This avoids `oneOf` ordering issues entirely.
3. Add test cases for combined schemas: `{"type": "object", "properties": {"a": {"type": "string"}}, "oneOf": [{"required": ["a"]}, {"required": ["b"]}]}`.

**Detection:** Test with real-world schemas. OpenAPI schemas frequently use `type: "object"` with `allOf` or `oneOf`. If combinator branches disappear, the ordering is wrong.

**Phase:** Decoder improvement phase (independent of rendering).

---

## Moderate Pitfalls

### Pitfall 4: $defs Support Creates Duplicate Key Conflicts

**What goes wrong:** When supporting both `definitions` and `$defs`, the decoder must merge them into a single `Definitions` dict. If the same definition name exists in both (unlikely but possible), one silently overwrites the other. More critically, `$defs` uses `#/$defs/` as the ref prefix while `definitions` uses `#/definitions/` — but the current code hardcodes `#/definitions/` prefix in `definitionsDecoder` and `extractRefName` drops exactly 14 characters (`#/definitions/` length) with `String.dropLeft 14`.

**Concrete location in code:**
- `definitionsDecoder`: `field "definitions" (keyValuePairs schemaDecoder |> map (List.map (Tuple.mapFirst ((++) "#/definitions/")) >> Dict.fromList))`
- `extractRefName`: `String.dropLeft 14 ref` — the literal 14 is the length of `"#/definitions/"`. A `$defs` ref like `"#/$defs/Foo"` would drop 14 characters producing `efs/Foo"` — wrong.
- Tests for `extractRefName` only cover `"#/definitions/Address"`, not `"#/$defs/Foo"`.

**Prevention:**
1. Decode both fields, prefix keys appropriately (`#/definitions/` and `#/$defs/`).
2. Update `extractRefName` to handle both prefixes:
   ```elm
   extractRefName ref =
       if String.startsWith "#/definitions/" ref then
           String.dropLeft 14 ref
       else if String.startsWith "#/$defs/" ref then
           String.dropLeft 8 ref
       else
           ref
   ```
3. Merge with `Dict.union` (left-biased), documenting which takes precedence.
4. Add test cases with `$defs` schemas and `$ref: "#/$defs/Foo"` references.

**Phase:** Decoder improvement phase. The existing test for `extractRefName` will need a companion test for the `$defs` prefix.

---

### Pitfall 5: Multi-Line SVG Text Requires Manual tspan Management

**What goes wrong:** SVG `<text>` elements do not wrap text. A long description or list of enum values renders as a single line that overflows the node boundary. There is no CSS `text-overflow: ellipsis` equivalent that works reliably in SVG 1.1.

**Concrete location in code:** The current `viewNameGraph` renders `Svg.text_` with a single `Svg.text` child. There is no wrapping or truncation. `roundRect` similarly uses `caption txt` as a single text node.

**Prevention:**
1. Manually split text into lines and render each as a `<tspan>` with `dy` attribute for line spacing:
   ```elm
   multiLineText : Float -> Float -> Float -> List String -> List (Svg msg)
   multiLineText x y lineHeight lines =
       List.indexedMap (\i line ->
           Svg.tspan
               [ SvgA.x (String.fromFloat x)
               , SvgA.dy (if i == 0 then "0" else String.fromFloat lineHeight)
               ]
               [ Svg.text line ]
       ) lines
   ```
2. Truncate long descriptions to a max character count with ellipsis BEFORE rendering (not in SVG).
3. For enum values, show first N values with "+M more" suffix.
4. Set a `maxNodeHeight` to prevent pathologically long nodes from dominating the diagram.

**Phase:** Information density phase. Depends on Pitfall 1 (NodeLayout) being resolved first, since multi-line content increases node height.

---

### Pitfall 6: Color System Becomes Unmaintainable Without Central Theme

**What goes wrong:** The current renderer has two colors: `darkClr` (blue fill) and `lightClr` (gray text/stroke). Adding type-based colors (different colors per schema type) by sprinkling color values throughout `viewSchema`, `iconRect`, `roundRect`, etc. creates a maintenance nightmare. Changing the palette later requires finding and updating dozens of call sites.

**Concrete location in code:** `darkClr` and `lightClr` are module-level constants used by `roundRect`, `iconRect`, `viewNameGraph`, `separatorGraph`, `iconGeneric`, and `connectorPath`. They are referenced as `SvgA.fill`, `SvgA.stroke`. If you add per-type color by branching on `Icon` inside `iconRect`, you end up with color logic scattered across a single 500-line function.

**Prevention:**
1. Define a `Theme` record with all colors upfront:
   ```elm
   type alias Theme =
       { background : String
       , objectStroke : String
       , arrayStroke : String
       , stringStroke : String
       , numberStroke : String
       , booleanStroke : String
       , refStroke : String
       , textColor : String
       , connectorColor : String
       }
   ```
2. Thread the `Theme` through rendering functions (or define a module-level constant for now).
3. Map `Schema` variant to color in ONE function: `strokeColorForSchema : Schema -> String`.
4. Do NOT use the `avh4/elm-color` library for SVG attributes — SVG attributes are strings, so hex strings are simpler and avoid Color-to-string conversion overhead.

**Phase:** Blueprint visual style phase. Establish the theme record before touching colors anywhere else.

---

### Pitfall 7: Connector Line Anchor Points Assume Fixed Node Height

**What goes wrong:** Connector lines currently anchor at `y + 14` (vertical center of a 28px pill). With variable-height multi-line nodes, the anchor should be at the vertical center of the actual node, not at a hardcoded offset. Parent-to-child connectors will visually disconnect from pill centers.

**Concrete location in code:**
- `viewProperties` inner `viewProps`: `connectorPath ( parentRightX, parentY + 14 ) ( x, y + 14 )`
- `viewItems` inner `viewItems_`: `connectorPath ( parentRightX, parentY + 14 ) ( x, y + 14 )`
- `viewSchema` Array branch: `connectorPath ( w, y + 14 ) ( w + 10, y + 14 )`

The `14` is `pillHeight / 2`. For variable-height nodes it must be `nodeHeight / 2`.

**Prevention:**
1. Have each node return its connector anchor point as part of its dimensions/layout result:
   ```elm
   type alias NodeResult =
       { svg : Svg msg
       , rightX : Float
       , bottomY : Float
       , anchorY : Float  -- vertical center for connector attachment
       }
   ```
2. Update `viewProperties` and `viewItems` to use the returned `anchorY` instead of `y + 14`.
3. This is tightly coupled with Pitfall 1 — solve them together.

**Phase:** Must be addressed alongside Pitfall 1 (NodeLayout refactor). Cannot be left for later without causing connector line misalignment.

---

### Pitfall 8: Schema Type Union Extension Breaks Exhaustive Pattern Matches

**What goes wrong:** If v1.1 adds a new `Schema` variant (e.g., `ObjectWithCombinator` for the combined type+combinator case, or if decoder changes produce a new structural representation), all pattern matches on `Schema` in `Render.Svg.viewSchema` and `Json.Schema.getName` must be updated. Elm's compiler will catch this — but only if the pattern match is truly exhaustive. If a `Fallback _ ->` or wildcard catch-all is present (and it is — `Schema.Fallback _` renders as empty `Svg.g`), a new variant will silently route to the fallback instead of erroring.

**Concrete location in code:**
- `viewSchema` has 12 cases ending with `Schema.Fallback _ -> ( Svg.g [] [], coords )`
- `Json.Schema.getName` has 12 cases ending with `Fallback _ -> Nothing`
- Adding any new Schema constructor without updating both functions will silently no-op in rendering

**Prevention:**
1. Before adding any new `Schema` variant, grep for every pattern match on `Schema` in the codebase.
2. Prefer restructuring existing variants over adding new ones. For combined object+combinator, add fields to `ObjectSchema` rather than a new union variant.
3. If a new variant is unavoidable, temporarily remove the `Fallback` wildcard to force compilation errors at every match site, add the new case, then restore `Fallback`.

**Phase:** Decoder improvement phase, before any Schema type changes.

---

### Pitfall 9: viewSchema Drops the `title` Field for All Schema Types

**What goes wrong:** The v1.1 goal includes showing node titles. The `Schema` type carries `title : Maybe String` on every variant (Object, Array, String, Integer, Number, Boolean, Null, Ref, combinators). The decoder decodes `title`. But `viewSchema` never reads it — it only passes the `name` argument (which comes from the property key, not the schema's own title). Rendering titles requires threading a new piece of information through every viewSchema call without breaking the existing name/weight contract.

**Concrete location in code:**
- `viewSchema` signature: `Maybe Name -> String -> Schema -> ...` where `Name = String`. The `name` argument is the property key passed from the parent, not the schema's title.
- For schemas that appear as $ref expansions or combinator sub-schemas, `name` may be `Nothing`. The `title` from the schema itself is ignored in every branch.
- `Schema.Object { title, properties }` — `title` is destructured but never used in the Object branch.
- Same for Array, String, Integer, Number, Boolean, Null, Ref.

**Prevention:**
1. When displaying a node label, prefer: property key (from `name`) > schema title > type name (fallback).
2. Implement as a helper: `nodeLabel : Maybe Name -> Schema -> String`.
3. Do NOT add a separate `title` argument to `viewSchema` — read it from the `Schema` argument directly in the render function.

**Phase:** Information density phase. This is a rendering addition, not a schema change.

---

### Pitfall 10: `iconRect` Passes Weight as String Through Multiple Layers

**What goes wrong:** `iconRect` accepts `weight : String` ("700" or "400") and passes it to `viewNameGraph`. The `iconGraph` function ignores weight entirely — all icon labels render at "700" regardless. Adding new typographic states (light weight for descriptions, italic for optional annotations) via the same string threading pattern leads to typos and inconsistency.

**Concrete location in code:**
- `iconRect : Icon -> Maybe String -> String -> Coordinates -> ( Svg msg, Dimensions )` — third arg is weight
- `iconGraph` internally calls `iconGeneric` and `viewNameGraph "700"` with hardcoded weight, ignoring the weight parameter for the icon portion
- `separatorGraph` does not take a weight argument at all

**Prevention:** Define a union type early:
```elm
type FontWeight = Bold | Normal | Light | Italic
```
Convert to SVG attributes at the render boundary only. This also makes the "required = bold, optional = normal" rule explicit and type-safe rather than string-based.

**Phase:** Blueprint visual style phase. Change before adding new typographic variants.

---

### Pitfall 11: `toSvgCoordsTuple` Returns Wrong Coordinate Type

**What goes wrong:** The helper `toSvgCoordsTuple : ( List (Svg msg), Coordinates ) -> ( Svg msg, Coordinates )` wraps a list in `Svg.g` and returns `Coordinates` (which is aliased to `(Float, Float)`, the same type as `Dimensions`). Both `Coordinates` and `Dimensions` are type aliases for `(Float, Float)`, so they are interchangeable — the compiler cannot distinguish them. A function that returns `Coordinates` when it should return `Dimensions` (or vice versa) will not produce a type error.

**Concrete location in code:**
```elm
type alias Coordinates = ( Float, Float )
type alias Dimensions = ( Float, Float )
```
These two aliases are nominally different but structurally identical. `toSvgCoordsTuple` is called in `viewSchema` Object branch returning `Coordinates` where the caller expects `Dimensions`. Currently they happen to hold the same values, but this is fragile.

**Prevention:** If adding a `NodeResult` record (see Pitfall 7), the distinction dissolves — both become fields of the record with clear names. If keeping the tuple approach, add a comment convention distinguishing "Coordinates = input position" from "Dimensions = output extent."

**Phase:** NodeLayout refactor phase.

---

### Pitfall 12: Lazy Rendering Interacts With Collapse State

**What goes wrong:** The codebase imports `Svg.Lazy` (`import Svg.Lazy exposing (lazy)`) but does not currently use it. If `Svg.Lazy.lazy` is added for performance on large schemas, it caches SVG based on argument equality. The `collapsedNodes : Set String` argument must be passed to every lazily-evaluated render function — otherwise a node will render its cached (pre-collapse) state even after the user toggles it.

**Concrete location in code:** The `lazy` import exists in `Render.Svg` but is unused. `view` passes `collapsedNodes` down through `viewSchema` → `viewProperties` / `viewItems` chain. Any `lazy` wrapping must include `collapsedNodes` as an argument, not just the schema and coordinates.

**Prevention:** If using `Svg.Lazy.lazy`, the function must take `collapsedNodes` as its first argument so Elm's structural equality check detects changes. Never lazy-wrap a function that closes over `collapsedNodes` via a closure — changes to the set will be invisible to the cache check.

**Phase:** Performance optimization phase (not v1.1 scope, but flag it if `lazy` is introduced during visual changes as an optimization).

---

## Minor Pitfalls

### Pitfall 13: Enum Value Rendering Creates Unbounded Node Width

**What goes wrong:** Enum values like `["very_long_option_name_1", "very_long_option_name_2", ...]` rendered inline make nodes extremely wide, breaking the horizontal layout.

**Prevention:** Render enum values vertically (one per line) within the node, with truncation after N items. Use `computeTextWidth` on the longest value to determine node width.

**Phase:** Information density phase.

---

### Pitfall 14: Description Text May Contain Characters That Break SVG

**What goes wrong:** JSON Schema descriptions can contain `<`, `>`, `&` characters. While Elm's `Svg.text` function handles escaping, if descriptions are used in SVG attributes (like title/tooltip), they need manual escaping.

**Prevention:** Always use `Svg.text` for text content (which auto-escapes). Never interpolate user text into attribute strings. If adding `<title>` elements for tooltips, use `Svg.title [] [ Svg.text description ]`.

**Phase:** Information density phase.

---

### Pitfall 15: Blueprint Dark Background Requires Contrast Audit of All Existing Colors

**What goes wrong:** The current colors (`darkClr = color 57 114 206` = `#3972CE` fill, `lightClr = "#e6e6e6"` text/stroke) were designed for a light/white page background. Moving to a dark navy blueprint background (`#1a2332` range) requires re-evaluating all colors. The `#3972CE` blue node fill will look different (likely higher contrast, which is fine). The `#8baed6` connector line color may need adjustment. The `#e6e6e6` text on dark-fill nodes will still work, but text on the page background (labels, etc.) may need to be lighter.

**Prevention:** When switching to dark background, audit every color in the renderer: `darkClr`, `lightClr`, the `#8baed6` connector, and the `#e6e6e6` text. Verify WCAG AA contrast (4.5:1 for text, 3:1 for UI components) against the new background.

**Phase:** Blueprint visual style phase, first step before any other visual changes.

---

### Pitfall 16: Existing Tests Only Cover Helpers, Not Layout

**What goes wrong:** The test suite covers `connectorPathD`, `extractRefName`, and `fontWeightForRequired` — all pure helper functions. No tests verify that `viewSchema` returns correct dimensions for any schema. Layout regressions from v1.1 changes will be undetected.

**Prevention:** Add dimension-verification tests before making changes:
```elm
test "object with two properties returns expected dimensions" <|
    \_ ->
        let
            (_, (w, h)) = viewSchema ... simpleObjectSchema
        in
        Expect.all
            [ \(w_, _) -> Expect.greaterThan 0 w_
            , \(_, h_) -> Expect.greaterThan 56 h_  -- at least 2 * pillHeight
            ] (w, h)
```

**Phase:** Before any layout changes. Add layout dimension tests as the first task in the NodeLayout refactor phase.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Blueprint visual style (dark background) | Existing light-background colors (#3972CE, #e6e6e6, #8baed6) need contrast audit | Audit all colors first; define Theme record before touching any color value |
| Blueprint visual style (outlined nodes) | Changing from filled to stroked rects: white text on transparent background is invisible | Define stroke+fill pairs per type, ensure text remains readable against page background |
| Multi-line nodes | Height calculation cascade: every function that adds `pillHeight` or `28` must change | Extract NodeLayout record FIRST, then change rendering |
| Typography hierarchy | Text width approximation breaks for different font sizes | Build per-size width function, keep monospace |
| Layout improvements | Spacing changes interact with connector anchor points | Change spacing constants AFTER NodeLayout refactor |
| Adding Schema type variants | Fallback wildcard hides missing pattern match cases | Temporarily remove Fallback to force exhaustive compile errors |
| Decoder: $defs support | `extractRefName` hardcodes prefix length 14 with `String.dropLeft 14` | Handle both prefixes, add tests with $defs schemas |
| Decoder: combined object+oneOf | oneOf order determines which decoder wins; Object decoder matches before combinators | More specific decoders must come first in chain |
| Long descriptions/enums | SVG text has no wrapping; unbounded content breaks layout | Truncate in Elm before rendering, use tspan for multi-line |
| Title field rendering | `viewSchema` destructs `title` from every variant but never renders it | Implement `nodeLabel` helper that prefers property key > title > type name |
| Font weight extension | Weight passed as String "700"/"400" through multiple layers | Replace with FontWeight union type before adding new typographic variants |

---

## Recommended Change Order

Based on pitfall dependencies, the safest implementation order is:

1. **Layout dimension tests** (Pitfall 16) — Establish regression baseline before any changes
2. **Decoder changes** (Pitfalls 3, 4) — Independent of rendering, testable in isolation
3. **NodeLayout refactor** (Pitfalls 1, 7, 11) — Extract the coordinate contract before changing it; includes adding `anchorY` to avoid connector disconnection
4. **Theme/color system** (Pitfalls 6, 15) — Visual-only, but must precede any color additions; dark background contrast audit first
5. **Blueprint style** (Pitfall 10) — Font weight union type, stroke/fill per type
6. **Text width per font-size** (Pitfall 2) — Needed before typography changes
7. **Multi-line text rendering** (Pitfall 5) — Depends on NodeLayout and text width
8. **Information density** (Pitfalls 9, 13, 14) — Title field, description, constraints, enums; after layout stabilizes
9. **Schema type changes** (Pitfall 8) — Only if needed; prefer field additions over new union variants

---

## Sources

- Source code reading: `/home/eelco/Source/elm/jsonschema-viewer/src/Render/Svg.elm` (all coordinate-threading details are direct observations from lines 28-512)
- Source code reading: `/home/eelco/Source/elm/jsonschema-viewer/src/Json/Schema/Decode.elm` (oneOf order, extractRefName hardcoding)
- Source code reading: `/home/eelco/Source/elm/jsonschema-viewer/src/Json/Schema.elm` (type aliases, Fallback variant)
- [SVG text-overflow - MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/text-overflow) - SVG text truncation limitations
- [Multiline SVG Text via tspan - O'Reilly](https://www.oreilly.com/library/view/svg-text-layout/9781491933817/ch04.html) - tspan-based multi-line approaches
- [JSON Schema $defs vs definitions discussion](https://github.com/orgs/json-schema-org/discussions/253) - $defs compatibility across drafts
- [JSON Schema combining keywords](https://json-schema.org/understanding-json-schema/reference/combining) - oneOf/anyOf/allOf semantics
- [SVGTextContentElement.getComputedTextLength() - MDN](https://developer.mozilla.org/en-US/docs/Web/API/SVGTextContentElement/getComputedTextLength) - browser text measurement API
- [Elm JSON Decode oneOf source](https://github.com/elm/json/blob/master/src/Json/Decode.elm) - sequential decoder behavior
- [JSON Schema 2020-12 Release Notes](https://json-schema.org/draft/2020-12/release-notes) - $defs migration details
- [WCAG 2.1 contrast requirements](https://www.w3.org/TR/WCAG21/#contrast-minimum) - 4.5:1 for text, 3:1 for UI components
