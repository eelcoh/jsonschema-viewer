# Architecture Patterns

**Domain:** Elm 0.19.1 JSON Schema SVG Viewer - v1.1 Professional Visuals
**Researched:** 2026-04-09

## Current Architecture (v1.0 Actual State)

The codebase has a clean three-layer structure across 4 source files (1,806 lines total):

```
Main.elm (448 lines) — Browser.element, state machine, wiring
  |
  +-- Json.Schema (325 lines)          — Schema union type, all record aliases
  +-- Json.Schema.Decode (170 lines)   — JSON -> Schema.Model decoder
  +-- Render.Svg (863 lines)           — Schema -> SVG with coordinate-threading
```

The earlier ARCHITECTURE.md proposed `Render.Theme` and `Render.Node` modules, but these were NOT built in v1.0. All style values remain as inline literals or module-level constants in `Render.Svg`. The `ObjectWithCombinator` Schema variant was also proposed but not added. This document reflects the actual codebase state.

### Actual Data Flow

```
JSON string (textarea / file upload)
    |
    v (via debounced Msg in Main.elm)
Json.Schema.Decode.decoder : Decoder Schema.Model
    |
    v
Schema.Model { definitions : Definitions, schema : Schema }
    |
    v (stored in Main.elm model)
Render.Svg.view toggleMsg collapsedNodes defs schema
    |
    v
viewSchema Set.empty defs collapsedNodes toggleMsg "root" (0,0) Nothing "700" schema
    |
    For each schema node in the tree:
      iconRect / roundRect  -- returns (Svg msg, Dimensions)
      clickableGroup        -- wraps with click handler (if collapsible)
      viewProperties / viewItems / viewMulti  -- recursive, accumulates Y
      connectorPath         -- emitted per child before recursive call
    |
    v
Svg.svg [ viewBox (computed from Dimensions) ] [ schemaView ]
```

### Coordinate-Threading Pattern (Actual Implementation)

Every render function signature ends with `Coordinates -> (Svg msg, Dimensions)` or returns `(List (Svg msg), Coordinates)`.

- `Coordinates = (Float, Float)` — `(x, y)` top-left origin of where to place this element
- `Dimensions = (Float, Float)` — `(rightEdgeX, bottomEdgeY)` after placing the element

Children are placed at `(parentRightEdge + 10, parentY)` horizontally. The 10px gap is both the connector gap and the indent constant (`ySpace = 10`).

**Key invariant:** `viewProperties` and `viewItems` accept `parentRightX` and `parentY` as separate floats (not as Coordinates) specifically to emit connector lines from `(parentRightX, parentY + 14)` to `(childX, childY + 14)`. The `+ 14` is half of `pillHeight = 28`.

### Current Style Constants (All in Render.Svg)

```elm
ySpace = 10           -- horizontal gap between parent and children
pillHeight = 28       -- hardcoded everywhere: rect height, connector midpoint, viewNameGraph dims
charWidth = 7.2       -- used in computeTextWidth
darkClr = color 57 114 206  -- "#3972ce" node fill
lightClr = "#e6e6e6"  -- text, stroke, separator color
connectorStroke = "#8baed6"  -- only used in connectorPath
strokeWidth = "0.2"   -- rect borders
separatorStrokeWidth = 1.2
cornerRadius = "2"    -- rx/ry on rects
refDashPattern = "5 3"  -- strokeDasharray on IRef nodes
```

These are NOT in a Theme record — they are scattered through `roundRect`, `iconRect`, `separatorGraph`, `iconGeneric`, `connectorPath`, `viewNameGraph`.

### Current Schema Type (Json.Schema)

```elm
type Schema
    = Object ObjectSchema
    | Array ArraySchema
    | String StringSchema
    | Integer IntegerSchema
    | Number NumberSchema
    | Boolean BooleanSchema
    | Null NullSchema
    | Ref RefSchema
    | OneOf BaseCombinatorSchema
    | AnyOf BaseCombinatorSchema
    | AllOf BaseCombinatorSchema
    | Fallback Json.Decode.Value
```

`BaseSchema` has `title`, `description`, `examples`. `StringSchema` has `minLength`, `maxLength`, `pattern`, `format`. Number/integer schemas have `minimum`, `maximum`. These fields exist but are NOT rendered — they are decoded and stored but never surfaced in the SVG.

### Current Decoder State (Json.Schema.Decode)

`definitionsDecoder` only looks for the `"definitions"` key:
```elm
field "definitions" (keyValuePairs schemaDecoder |> map (...prefix "#/definitions/"))
```
`$defs` (JSON Schema 2020-12) is not supported. A schema using `$defs` will decode with empty definitions, making all `$ref` nodes display as unresolvable labels.

`schemaDecoder` uses `oneOf` with 12 branches. Because `object` is checked first and requires `"type": "object"`, a schema with both `"type": "object"` and `"oneOf"` will match the object branch and silently drop the `oneOf` field.

`extractRefName` strips exactly 14 characters (`String.dropLeft 14`), which correctly strips `#/definitions/` (14 chars) but would produce a wrong result for `#/$defs/` (8 chars) without modification.

## Architecture for v1.1: Integration Points

### Integration Point 1: Style/Theme Extraction (Render.Svg refactor)

**What:** Extract all hardcoded style values from `Render.Svg` into a `Render.Theme` module as a record.

**New module:** `src/Render/Theme.elm` with `type alias Theme` and `default : Theme`.

**Integration:** `view` gains a `Theme` parameter. This threads down through `viewSchema`, `viewProperties`, `viewItems`, `viewMulti`, `iconRect`, `roundRect`, `separatorGraph`, `iconGeneric`, `viewNameGraph`, `connectorPath`.

**Change surface:** Every render function in `Render.Svg` gains `Theme` as first parameter. This is mechanical: no behavior change, output SVG is pixel-identical. Testable with compile check only.

**Why now, before visual changes:** All subsequent visual changes (colors, sizing, spacing) modify Theme values. Without this refactor, each visual change requires hunting through multiple functions.

**Suggested Theme fields for v1.1 blueprint style:**

```elm
type alias Theme =
    { -- Node colors (type-coded)
      objectColor : String      -- Object nodes
    , arrayColor : String       -- Array nodes
    , stringColor : String      -- String nodes
    , numberColor : String      -- Number/Integer nodes
    , boolColor : String        -- Boolean nodes
    , nullColor : String        -- Null nodes
    , refColor : String         -- Ref nodes
    , combinatorColor : String  -- OneOf/AnyOf/AllOf nodes
    , nodeText : String         -- Text on all nodes
    , connectorStroke : String  -- Bezier curves

    -- Typography
    , fontFamily : String
    , fontSize : Float
    , charWidth : Float         -- for computeTextWidth

    -- Layout
    , pillHeight : Float        -- single-line node height
    , nodeHPadding : Float      -- horizontal padding inside pill
    , nodeVPadding : Float      -- vertical padding for multi-line
    , childIndent : Float       -- horizontal gap between parent and children
    , siblingGap : Float        -- vertical gap between siblings

    -- Node shape
    , cornerRadius : Float
    , strokeWidth : Float
    , refDashPattern : String
    , connectorWidth : Float
    , separatorWidth : Float

    -- Typography weights
    , requiredWeight : String
    , optionalWeight : String
    }
```

**Color-coding integration:** `iconRect` currently uses `darkClr` uniformly for all node fills. With Theme, `iconRect` receives an `Icon` to look up the correct color from Theme:

```elm
nodeColor : Theme -> Icon -> String
nodeColor theme icon =
    case icon of
        IObject -> theme.objectColor
        IList   -> theme.arrayColor
        IStr    -> theme.stringColor
        IInt    -> theme.numberColor
        IFloat  -> theme.numberColor
        IBool   -> theme.boolColor
        INull   -> theme.nullColor
        IRef _  -> theme.refColor
        IFile   -> theme.objectColor
```

This is the key integration point for blueprint-style color coding — one function maps icon to theme color.

### Integration Point 2: Information Density on Nodes (Render.Svg + Render.Node)

**What:** Show description, constraints (minLength/maxLength, minimum/maximum, pattern), format annotations, and enum values on pills. Currently only the field name appears.

**Problem:** `pillHeight = 28` is assumed constant in connector midpoint math (`+ 14`), rect height attributes (`"28"`), and dimension returns (`28 + y`). Multi-line nodes break this assumption.

**Solution: `Render.Node` module with measure-then-render split**

New module `src/Render/Node.elm` provides:

```elm
type alias NodeLine =
    { text : String
    , style : LineStyle
    }

type LineStyle
    = Primary    -- icon + name, bold
    | Secondary  -- description, smaller/lighter
    | Tertiary   -- constraints/format, smallest

type alias NodeContent =
    { icon : Icon
    , lines : List NodeLine
    , isDashed : Bool
    }

type alias NodeMetrics =
    { width : Float
    , height : Float       -- varies with line count
    , anchorY : Float      -- connector attachment point (vertical center of first line)
    }

nodeContentFromSchema : Schema -> Maybe String -> NodeContent
measure : Theme -> NodeContent -> NodeMetrics
render : Theme -> Coordinates -> NodeContent -> NodeMetrics -> Svg msg
```

**Integration with coordinate-threading:** The `+ 14` connector midpoint changes to `+ metrics.anchorY`. Every call to `connectorPath` that currently uses `y + 14` must use `y + metrics.anchorY` from the measured content. This is the highest-risk change because it touches all connector emission in `viewProperties`, `viewItems`, and the array `itemConnector`.

**Build order implication:** Build `Render.Node` after `Render.Theme` is extracted (so Theme is available to pass to `measure`), but before making visual changes that depend on variable node heights.

**What each Schema variant surfaces:**

| Schema Variant | Primary | Secondary | Tertiary |
|---------------|---------|-----------|---------|
| Object | name | description | minProperties/maxProperties |
| Array | name | description | minItems/maxItems |
| String | name | description | minLength/maxLength, pattern, format |
| Integer/Number | name | description | minimum/maximum, enum values |
| Boolean | name | description | enum values |
| Null | name | description | — |
| Ref | defName | — | — |
| OneOf/AnyOf/AllOf | combinator label | description | — |

**Connector attachment:** With multi-line pills, the connector should attach at the vertical center of the first line (Primary), not the center of the whole pill. `anchorY` = `theme.nodeVPadding + theme.fontSize * 0.7`.

### Integration Point 3: Decoder Fixes

#### 3a: $defs Support

**Location:** `Json.Schema.Decode.definitionsDecoder`

**Change:** Two-field lookup, merge results:

```elm
definitionsDecoder : Decoder Schema.Definitions
definitionsDecoder =
    let
        defsField key prefix =
            field key
                (keyValuePairs schemaDecoder
                    |> map (List.map (Tuple.mapFirst ((++) prefix)) >> Dict.fromList)
                )
                |> maybe
                |> map (Maybe.withDefault Dict.empty)
    in
    map2 Dict.union
        (defsField "definitions" "#/definitions/")
        (defsField "$defs" "#/$defs/")
```

**`extractRefName` fix:** Must handle both prefixes. Current `String.dropLeft 14` only works for `#/definitions/`. Correct fix:

```elm
extractRefName : String -> String
extractRefName ref =
    if String.startsWith "#/definitions/" ref then
        String.dropLeft 14 ref
    else if String.startsWith "#/$defs/" ref then
        String.dropLeft 8 ref
    else
        ref
```

**No Schema type changes needed.** `Definitions` remains `Dict String Schema`. The prefix is the lookup key convention.

**No Render.Svg changes needed.** `Dict.get ref defs` already handles whichever prefix the ref string uses, as long as both the stored key and the ref value use the same prefix.

**Risk:** Very low. Isolated to two functions. Existing tests will still pass.

#### 3b: Combined type+combinator schemas

**Problem:** A schema like `{"type": "object", "properties": {...}, "oneOf": [...]}` currently matches the `object` decoder branch (first match in `oneOf`) and the `oneOf` field is silently ignored.

**Recommended approach: New Schema variant**

```elm
-- Add to Json.Schema
type Schema
    = ...existing...
    | ObjectWithCombinator ObjectSchema CombinatorKind (List Schema)

type CombinatorKind = OneOfKind | AnyOfKind | AllOfKind
```

**Decoder change:** Add three specific decoders before the plain object decoder in `schemaDecoder`:

```elm
oneOf
    [ objectWithOneOfDecoder   -- NEW: type=object + oneOf
    , objectWithAnyOfDecoder   -- NEW: type=object + anyOf
    , objectWithAllOfDecoder   -- NEW: type=object + allOf
    , objectDecoder            -- existing: type=object only
    , ...
    ]
```

Each combined decoder requires both `"type": "object"` (via `withType`) AND the combinator field (`required "oneOf" ...`).

**Renderer addition:** Add a case to `viewSchema`:

```elm
Schema.ObjectWithCombinator objSchema kind subSchemas ->
    -- Render object pill (same as Object branch)
    -- If expanded: render properties (same as Object branch)
    --              then render combinator group below properties
    --              (reuse viewMulti pattern with sub-schema list)
```

**Risk:** Medium. New Schema variant requires adding a case to `viewSchema` and the `getName` function in `Json.Schema`. The `Fallback` pattern provides safety — if any test schema hits an unexpected state, it silently renders as empty rather than crashing.

### Integration Point 4: Blueprint Layout and Spacing

**What:** Adjust spacing constants in Theme to create breathing room: wider `childIndent`, larger `siblingGap`, increased `nodeHPadding`.

**Integration:** Pure Theme value changes after `Render.Theme` is extracted. No structural code changes needed.

**Connector style:** Change from `"#8baed6"` blue to a lighter blueprint-grid color. Pure Theme value.

**Node stroke style:** Blueprint style uses outlined nodes (transparent or very light fill, visible stroke) rather than solid-fill dark nodes. This changes `nodeFill` and `nodeStroke` in Theme, plus the text color inverts (currently light text on dark fill; blueprint uses dark text on light/transparent fill).

**Risk:** Low for spacing. Medium for fill/stroke inversion because text color, separator color, and border color all need to change together consistently.

### Integration Point 5: RenderContext Grouping (Optional, Recommended)

`viewSchema` currently has 9 parameters:
```elm
viewSchema : Set String -> Definitions -> Set String -> (String -> msg) -> String -> Coordinates -> Maybe Name -> String -> Schema -> (Svg msg, Dimensions)
```

With Theme added, this becomes 10. Consider grouping the stable-per-render-tree context:

```elm
type alias RenderContext msg =
    { theme : Theme
    , definitions : Definitions
    , collapsedNodes : Set String
    , toggleMsg : String -> msg
    }
```

This reduces `viewSchema` to:
```elm
viewSchema : RenderContext msg -> Set String -> String -> Coordinates -> Maybe Name -> String -> Schema -> (Svg msg, Dimensions)
```

7 parameters, and `RenderContext` is constructed once in `view` and threaded unchanged. This is a mechanical refactor with no behavior change, best done alongside the Theme extraction.

## Recommended Module Map for v1.1

```
Main.elm
  |
  +-- Json.Schema              (types: Schema union, ObjectSchema, StringSchema, etc.)
  +-- Json.Schema.Decode       (JSON -> Schema.Model; add $defs, add ObjectWithCombinator decoders)
  +-- Render.Theme             (NEW: Theme record, default blueprint theme)
  +-- Render.Node              (NEW: NodeContent, NodeMetrics, nodeContentFromSchema, measure, render)
  +-- Render.Svg               (MODIFIED: thread Theme/RenderContext, use Render.Node for pills)
```

| Module | Responsibility | Depends On | New vs Modified |
|--------|---------------|------------|-----------------|
| `Json.Schema` | Pure types only | Nothing | Modified (add ObjectWithCombinator, CombinatorKind) |
| `Json.Schema.Decode` | JSON -> Schema | `Json.Schema` | Modified ($defs, combined decoders) |
| `Render.Theme` | Visual config record | Nothing | NEW |
| `Render.Node` | Single-node measure + render | `Render.Theme`, `Json.Schema` | NEW |
| `Render.Svg` | Tree layout, coordinate-threading, connectors | All above | Modified (thread Theme, use Node) |
| `Main` | App state, wiring | All above | Minor (pass Theme to view) |

## Patterns to Follow

### Pattern 1: Record-as-Config Threading

Pass `Theme` (and optionally `RenderContext`) as the first parameter to all render functions. This is idiomatic Elm: no global state, no module-level mutable config. Every function explicitly receives what it needs.

Do not use CSS classes or a style sheet for SVG elements. SVG attribute styling is what the codebase already uses and is more portable.

### Pattern 2: Measure Before Render for Variable-Height Nodes

For multi-line pills, the coordinate-threading pattern requires knowing element height before placing children. The split into `nodeContentFromSchema -> NodeContent` followed by `measure theme content -> NodeMetrics` followed by `render` is the correct pattern. The `measure` step is pure and testable.

### Pattern 3: Decoder Ordering as Priority

In `Json.Decode.oneOf`, more specific decoders must precede more general ones. Combined decoders (object+combinator) must come before their component decoders (plain object, standalone combinator). Ordering is the only mechanism for priority — there is no explicit precedence.

### Pattern 4: Prefix Convention for Definitions Lookup

Definitions are stored with their full reference prefix as the key. A `$ref: "#/definitions/Foo"` is stored as `Dict.get "#/definitions/Foo"`. This means `$defs` entries must be stored as `"#/$defs/Foo"` — not normalized to a common prefix — to match `$ref` values from 2020-12 schemas without any additional lookup logic.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Style Logic in Schema Types

Do not add color or size information to `Json.Schema` types. Schema types represent parsed document structure, not visual presentation. Color decisions belong in `Render.Theme`; the mapping from schema variant to color belongs in `Render.Svg` or `Render.Node`.

### Anti-Pattern 2: Normalizing $defs and $definitions to a Single Prefix

It is tempting to normalize both to a common prefix during decode. However, this requires modifying all stored `$ref` values inside decoded schemas (since refs like `"#/$defs/Foo"` would no longer match after normalization). The current prefix-as-key convention is simpler: store what the ref says, look up what the ref says.

### Anti-Pattern 3: Flat Connector Midpoint (hardcoded +14)

After adding multi-line nodes, `y + 14` is wrong for taller pills. The measure-then-render pattern provides `metrics.anchorY` for the correct attachment point. Using `+ 14` anywhere after introducing variable-height pills will produce misaligned connectors.

### Anti-Pattern 4: Merging Combinator Sub-Schemas into Object Properties

For `ObjectWithCombinator`, the combinator sub-schemas are alternatives or constraints, not additional properties. Appending them to the object's `properties` list would lose semantic meaning and visually mislead. Render them as a distinct child branch (reusing `viewMulti` with a combinator label pill).

## Build Order (Dependency-Driven)

1. **Decoder fixes** (`$defs` support + `extractRefName`) — Isolated to `Json.Schema.Decode` and `Render.Svg` helper. No render changes. Lowest risk, provides immediate value for 2020-12 schemas. Zero dependencies on other v1.1 changes.

2. **`Render.Theme` extraction** — Move all style constants from `Render.Svg` into a Theme record. Thread through all render functions. No behavior change. Prerequisite for all visual changes.

3. **`RenderContext` grouping** (optional, can be done with Step 2) — Reduces function signature noise before adding more parameters for multi-line nodes.

4. **Blueprint style values** — Update Theme defaults: colors, stroke style, fill inversion, spacing. Pure value changes once Theme is extracted. Requires verifying text contrast after fill inversion.

5. **`ObjectWithCombinator` variant** — Add Schema variant, three new decoder branches, new `viewSchema` case. Medium complexity, isolated to decoder and renderer. Can be done before or after visual changes.

6. **`Render.Node` and multi-line pills** — Highest risk. Requires changing every `y + 14` connector attachment, every hardcoded `"28"` rect height, and every `28 + y` dimension return. Do this last so visual style is settled before layout math changes.

## Scalability Considerations

| Concern | v1.0 State | v1.1 Impact | Mitigation |
|---------|-----------|-------------|------------|
| Function parameter count | 9 params in viewSchema | Grows to 10+ without grouping | RenderContext record |
| Node height assumption | Hardcoded 28px everywhere | Variable height breaks 6+ sites | Measure-before-render pattern |
| Decoder branch count | 12 branches | Grows to 15 (3 combined decoders) | Ordering remains manageable |
| extractRefName fragility | Hardcoded dropLeft 14 | Breaks for #/$defs/ refs | Replace with startsWith guards |
| Style discoverability | Constants in 5+ functions | Theme centralizes all values | Render.Theme module |
| Text width accuracy | charWidth 7.2 × char count | Monospace approximation, acceptable | No change needed |

## Sources

- Direct codebase analysis of all 4 source files (HIGH confidence — read from actual implementation)
- JSON Schema draft-07 vs 2020-12 `$defs`/`definitions` distinction (HIGH confidence — well-documented spec change)
- Elm 0.19.1 module and record patterns (HIGH confidence — stable, well-established patterns)
