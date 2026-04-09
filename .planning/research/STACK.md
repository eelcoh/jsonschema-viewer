# Technology Stack

**Project:** JSON Schema Viewer v1.1 — Professional Visuals
**Researched:** 2026-04-09

## Current Stack (v1.0 — unchanged for v1.1)

| Technology | Version | Purpose |
|------------|---------|---------|
| Elm | 0.19.1 | Application framework |
| elm/svg | 1.0.1 | SVG rendering |
| elm/browser | 1.0.2 | Browser.element app |
| elm/json | 1.1.2 | JSON decoding |
| NoRedInk/elm-json-decode-pipeline | 1.0.0 | Ergonomic decoder pipelines |
| avh4/elm-color | 1.0.0 | Color type definitions |
| noahzgordon/elm-color-extra | 1.0.2 | Color conversion (hex), manipulation |
| elm-community/list-extra | 8.2.4 | List utilities |
| elm/file | 1.0.5 | File upload handling |

## Recommended Stack Changes for v1.1

**Zero new packages.** The existing stack is sufficient for every v1.1 goal. The rationale for each area follows.

## SVG Capabilities Already Available in elm/svg 1.0.1

**Confidence: HIGH** (verified via elm/svg source on GitHub)

`elm/svg` exposes the full SVG 1.1 spec as thin wrappers over `VirtualDom.node`. Every element needed for professional visuals is already present:

### Gradients and Visual Depth

| Element | Function | Purpose for v1.1 |
|---------|----------|-------------------|
| `Svg.defs` | Container for reusable definitions | Define gradients, filters, markers once |
| `Svg.linearGradient` | Linear gradient definition | Subtle node background gradients |
| `Svg.stop` | Gradient color stops | Color transitions within gradients |

### SVG Filters (Drop Shadows, Glow)

| Element | Purpose for v1.1 |
|---------|------------------|
| `Svg.filter` | Define reusable filter effects |
| `Svg.feGaussianBlur` | Blur primitive for soft shadows |
| `Svg.feOffset` | Shadow displacement |
| `Svg.feMerge` + `Svg.feMergeNode` | Combine shadow + original graphic |

Drop shadow pattern that works with elm/svg as-is:

```elm
Svg.defs []
    [ Svg.filter [ SvgA.id "dropShadow" ]
        [ Svg.feGaussianBlur
            [ SvgA.in_ "SourceAlpha", SvgA.stdDeviation "2" ] []
        , Svg.feOffset
            [ SvgA.dx "1", SvgA.dy "1", SvgA.result "offsetBlur" ] []
        , Svg.feMerge []
            [ Svg.feMergeNode [ SvgA.in_ "offsetBlur" ] []
            , Svg.feMergeNode [ SvgA.in_ "SourceGraphic" ] []
            ]
        ]
    ]
```

Note: `feDropShadow` (the CSS shorthand) is not in elm/svg, but the `feGaussianBlur + feOffset + feMerge` composition achieves identical results with more control.

### Additional SVG Elements for Polish

| Element | Purpose for v1.1 |
|---------|------------------|
| `Svg.clipPath` | Clip overflow text within node bounds |
| `Svg.marker` | Arrow/dot markers on connector endpoints |
| `Svg.style` | Embed CSS in SVG (hover effects, transitions) |
| `Svg.title` | Native browser tooltip on hover (no JS needed) |

### SVG Attributes (Svg.Attributes)

All presentation attributes are available as string-typed functions. Key ones for v1.1:

- `filter` — Reference filter by ID: `SvgA.filter "url(#dropShadow)"`
- `fill` — Accepts hex, rgb(), url(#gradientId)
- `opacity`, `fillOpacity`, `strokeOpacity` — Layered depth
- `strokeDasharray` — Already used for $ref dashed borders
- `fontFamily`, `fontSize`, `fontWeight`, `fontStyle` — Typography control
- `dominantBaseline`, `textAnchor` — Text alignment (already used)
- `letterSpacing` — Typography fine-tuning

## Why NOT to Add elm-tree-diagram

**Confidence: HIGH**

`brenden/elm-tree-diagram` (v3.0.0, Elm 0.19.1 compatible) provides a generic tree layout algorithm with `leftToRight`, `rightToLeft`, `topToBottom`, `bottomToTop` orientations and configurable `levelHeight`, `subtreeDistance`, `siblingDistance`.

However:

1. **Migration cost outweighs benefit.** The existing coordinate-threading pattern (`(Svg msg, Dimensions)` return pair) is working, tested, and understood. Rewriting ~500 lines of `Render.Svg` around elm-tree-diagram's layout model is high risk for no feature gain.
2. **Schema-viewer layout is not a generic tree.** Connector lines must attach to specific Y anchors (vertical center of variable-height pills). elm-tree-diagram positions node centers and does not expose raw anchor coordinates in the way this project needs.
3. **Variable-height nodes need custom measurement.** elm-tree-diagram assumes uniform node sizes or delegates size to callbacks. Multi-line nodes (description + constraints) require pre-measurement before layout — which the existing pattern already supports via the measure-then-render split.

**Verdict:** Keep the hand-rolled coordinate-threading pattern.

## Why NOT to Add typed-svg

**Confidence: HIGH**

`elm-community/typed-svg` (v7.0.0, Elm 0.19.1 compatible) provides type-safe SVG attributes (e.g., `Length` types instead of strings).

1. **Migration cost with no capability gain.** ~80+ attribute usages change signature throughout `Render.Svg`.
2. **Coordinate-threading already handles type safety.** Values are computed as `Float` and formatted via `String.fromFloat`. The weak-point (mixing up width/height) is not what typed-svg solves.
3. **Dependency weight.** Large transitive surface for marginal benefit.

**Verdict:** Stay with `elm/svg` string-attribute API.

## Color Management — Already Installed

The `avh4/elm-color` + `noahzgordon/elm-color-extra` pair provides everything needed for a blueprint theme:

| Package | Key API | Use for v1.1 |
|---------|---------|--------------|
| `avh4/elm-color` | `Color.rgb255`, `Color.hsl`, `Color.toRgba` | Define palette base colors |
| `noahzgordon/elm-color-extra` | `Color.Convert.colorToHex`, `Color.Manipulate.lighten/darken/fadeIn/fadeOut`, `Color.Interpolate.interpolate` | Derive color variants, convert to SVG hex strings |

### Hand-Roll: Render.Theme Module

Create `Render.Theme` to centralize all visual constants. A `Theme` record threads through render functions — one change site updates every node:

```elm
module Render.Theme exposing (Theme, blueprint)

type alias Theme =
    { background : String
    , nodeFill : String       -- per-type variant from typeColor
    , nodeStroke : String     -- per-type variant
    , textPrimary : String    -- property name
    , textSecondary : String  -- description
    , textTertiary : String   -- constraints/format
    , connectorStroke : String
    , fontFamily : String
    , fontSize : Float
    , secondaryFontSize : Float
    , tertiaryFontSize : Float
    , lineHeight : Float
    , nodeHPadding : Float
    , nodeVPadding : Float
    , childIndent : Float
    , siblingGap : Float
    , cornerRadius : Float
    , refDashPattern : String
    , connectorWidth : Float
    }
```

Type-to-color mapping uses the Okabe-Ito palette (colorblind-safe) adapted for dark backgrounds:

| Type | Hex | Notes |
|------|-----|-------|
| Object | `#56B4E9` | Sky Blue — structural/container |
| Array | `#CC79A7` | Reddish Purple — container, distinct from Object |
| String | `#009E73` | Bluish Green — near-universal string convention |
| Integer | `#E69F00` | Orange — numeric literal convention |
| Number | `#D4A017` | Gold — distinguishes from integer |
| Boolean | `#D55E00` | Vermilion — punchy, small binary type |
| Null | `#7A8B99` | Gray — muted for absent value |
| Ref | `#78D4F0` | Light sky blue + dashed border |
| Combinator | `#F0E442` | Yellow — attention-drawing for composition |

**Note:** `avh4/elm-color` Color values should be converted to hex strings AT the `Render.Theme` boundary. SVG attributes are strings; doing the conversion once in the theme module avoids repeated `colorToHex` calls in the hot render path.

## Font Metrics — Pure Elm Approximation

**Confidence: HIGH** (well-understood constraint)

Elm cannot call `getBBox()` or `getComputedTextLength()` without ports. The existing `computeTextWidth` uses a 7.2px/character constant for 12px monospace. For v1.1 with multiple font sizes, generalize to a ratio:

```elm
charWidthForSize : Float -> Float
charWidthForSize fontSize =
    fontSize * 0.6  -- monospace advance width is ~60% of em size

textWidth : Float -> String -> Float
textWidth fontSize text =
    toFloat (String.length text) * charWidthForSize fontSize
```

The 0.6 ratio is reliable for ASCII characters in monospace fonts across common screen sizes. JSON Schema property names are ASCII, so this holds. Unicode symbols in descriptions may be wider — truncate descriptions in Elm before rendering (max ~60 chars) rather than relying on exact width.

**No Elm package provides font metrics without DOM access.** This is a known constraint across the entire Elm SVG ecosystem.

## CSS-in-SVG Strategy

Split styling concerns by context:

| Concern | Location | Why |
|---------|----------|-----|
| App chrome (toolbar, panels) | `main.css` | CSS layout features, HTML hover states |
| SVG node appearance | Inline `SvgA.*` attributes | Computed from data (type colors, dimensions) |
| SVG hover effects + transitions | `Svg.style` element inside SVG | CSS `:hover` pseudo-class on SVG groups |

Embed a `<style>` inside the SVG for hover/transition effects with no JS interop:

```elm
Svg.style []
    [ Svg.text """
        .node { transition: opacity 0.15s ease; cursor: pointer; }
        .node:hover { opacity: 0.85; }
        .connector { transition: stroke-opacity 0.2s ease; }
    """ ]
```

**Do NOT use `rtfeldman/elm-css`.** It targets `Html.Styled`, not `Svg`. SVG styling is attribute-based in this project; elm-css adds significant complexity with zero benefit here.

## Decoder Improvements — No New Packages

### $defs Support (JSON Schema 2020-12)

The fix is a decoder change only. `Json.Schema.Decode.definitionsDecoder` currently looks for `"definitions"` only:

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

Refs are stored with their full prefix (`#/definitions/Foo`, `#/$defs/Bar`). `Dict.get ref defs` in `Render.Svg` already matches on full ref strings, so no render changes needed. `extractRefName` must handle both prefixes:

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

### Combined type + combinator Schemas

Add a new Schema union variant for `{"type": "object", "properties": {...}, "oneOf": [...]}` — a common pattern in OpenAPI schemas:

```elm
type Schema
    = ...existing...
    | ObjectWithCombinator ObjectSchema CombinatorKind (List Schema)

type CombinatorKind = OneOfKind | AnyOfKind | AllOfKind
```

Combined decoders must precede plain `objectDecoder` in the `oneOf` chain (more specific first):

```elm
schemaDecoder =
    lazy (\_ ->
        oneOf
            [ objectWithOneOfDecoder   -- BEFORE plain object
            , objectWithAnyOfDecoder
            , objectWithAllOfDecoder
            , objectDecoder
            , arrayDecoder
            , ...
            , oneOfDecoder
            , anyOfDecoder
            , allOfDecoder
            , map Schema.Fallback value
            ]
    )
```

## New Modules to Create (No New Packages)

| Module | Purpose | Status |
|--------|---------|--------|
| `Render.Theme` | Color palette, spacing constants, font sizes | New |
| `Render.Node` | NodeContent, NodeMetrics, measure, render split | New |

Optionally:
| `Render.Svg.Defs` | SVG `<defs>` block: gradients, filters, markers | New (or inline in `Render.Svg`) |

## Summary: Build vs Install

| Need | Solution | Install? |
|------|----------|----------|
| SVG gradients | `Svg.defs`, `Svg.linearGradient`, `Svg.stop` — already in elm/svg | No |
| Drop shadows | `Svg.filter` + filter primitives — already in elm/svg | No |
| Type-based color palette | Hand-rolled `Render.Theme` using avh4/elm-color (installed) | No |
| Color variants | `Color.Manipulate.lighten/darken` from elm-color-extra (installed) | No |
| Font metrics | Hand-rolled `fontSize * 0.6` ratio | No |
| SVG hover effects | `Svg.style` embedded in SVG | No |
| Multi-line nodes | Hand-rolled `Render.Node` with `measure`/`render` split | No |
| `$defs` support | Modify `Json.Schema.Decode` only | No |
| Combined object+combinator schemas | New `Schema` variant + decoder branches | No |
| Blueprint visual style | Color constants in `Render.Theme` + SVG attributes | No |

**Zero new dependencies for v1.1.**

## Installation

No changes to `elm.json`.

```bash
# Verify install is clean
elm make src/Main.elm --output=/dev/null
```

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Tree layout | Hand-rolled coordinate-threading | `brenden/elm-tree-diagram` | Migration cost, variable-height node mismatch |
| SVG attributes | `elm/svg` string API | `elm-community/typed-svg` | No capability gain, 80+ call sites change |
| CSS styling | Inline SVG attributes + embedded `<style>` | `rtfeldman/elm-css` | Targets Html.Styled, not SVG |
| Font metrics | `fontSize * 0.6` ratio | Ports + `getComputedTextLength()` | Adds JS interop, async complexity, out of scope |

## Sources

- [elm/svg source — full element list](https://github.com/elm/svg/blob/master/src/Svg.elm) — HIGH confidence
- [elm/svg package docs](https://package.elm-lang.org/packages/elm/svg/latest/Svg) — HIGH confidence
- [brenden/elm-tree-diagram — package docs](https://package.elm-lang.org/packages/brenden/elm-tree-diagram/latest/TreeDiagram-Svg) — HIGH confidence (verified via Elm package registry)
- [noahzgordon/elm-color-extra](https://package.elm-lang.org/packages/noahzgordon/elm-color-extra/latest/) — HIGH confidence
- [avh4/elm-color](https://package.elm-lang.org/packages/avh4/elm-color/latest/) — HIGH confidence
- [Okabe-Ito colorblind-safe palette](https://easystats.github.io/see/reference/scale_color_okabeito.html) — HIGH confidence (peer-reviewed color science)
- [JSON Schema $defs vs definitions](https://github.com/orgs/json-schema-org/discussions/253) — HIGH confidence
- [JSON Schema 2020-12 release notes](https://json-schema.org/draft/2020-12/release-notes) — HIGH confidence
- [SVG drop shadow filter technique](https://www.w3.org/TR/filter-effects/) — HIGH confidence (W3C spec)
- [Monospace font advance width ratio](https://en.wikipedia.org/wiki/Monospaced_font) — HIGH confidence
