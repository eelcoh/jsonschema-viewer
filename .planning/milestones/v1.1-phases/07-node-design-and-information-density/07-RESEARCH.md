# Phase 7: Node Design and Information Density - Research

**Researched:** 2026-04-12
**Domain:** Elm 0.19.1 SVG rendering — node visual design, hover overlays, icon dispatch
**Confidence:** HIGH

## Summary

This phase adds visual distinction for required properties (amber border) and richer type icons (format-as-type, enum-as-type) to pill nodes, plus a custom SVG hover overlay that surfaces metadata (description, constraints, enum values) on demand. All changes are confined to `Render.Svg.elm`, `Render.Theme.elm`, and `Main.elm` — no new Elm packages are needed.

The architecture is entirely locked by prior phases and the CONTEXT.md decisions. The coordinate-threading `(Svg msg, Dimensions)` pattern must not be disturbed. The hover overlay is the only new structural concept: it lives outside the coordinate-threaded layout and is rendered last in the SVG tree.

The primary risk is `iconRect`'s signature change (`isRequired : Bool` param) cascading to all call sites. The secondary risk is the hover-state plumbing: `Render.Svg.view` gains three new parameters, which must propagate through every `viewSchema` / `viewProperty` call in the module. A clean approach is to thread a `HoverConfig` record rather than three separate parameters.

**Primary recommendation:** Implement in four sequential tasks: (1) Theme constants, (2) Icon type extension + `iconRect` required-border, (3) Hover state wiring in Main.elm + `view` signature, (4) `viewHoverOverlay` function. Keep `pillHeight = 28` immutable throughout.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Required properties have an amber/warm-colored border instead of default #a0c4e8. Optional properties keep default border color. Color-based distinction only — no asterisk, dot, or badge.
- **D-02:** Required properties also keep bold font weight (from Phase 2). Double signal: amber border + bold text for required, default border + normal weight for optional.
- **D-03:** Add `requiredBorder` color constant to `Render.Theme`.
- **D-04:** Well-known string formats (Email, DateTime, Hostname, Ipv4, Ipv6, Uri) replace the 'S' icon in the type position with a distinct icon.
- **D-05:** Custom string formats (`Custom String` variant) show the format name as text in the icon position, replacing 'S'.
- **D-06:** Strings without a format keep the existing 'S' icon unchanged.
- **D-07:** When a node has `enum` values, the type icon is replaced with an 'Enum' icon/text regardless of base type. The base type is visible in the hover overlay.
- **D-08:** The actual enum values are shown in the hover overlay, not on the pill.
- **D-09:** All nodes with metadata (description, constraints, enum values, format details) show a custom SVG overlay panel on mouse hover. The overlay appears near the node without shifting the diagram layout.
- **D-10:** The overlay is implemented as SVG elements rendered by Elm using `Svg.Events.onMouseOver` / `Svg.Events.onMouseOut` — NOT browser-native `<title>` tooltips. This is a custom Elm-rendered panel.
- **D-11:** Hover overlays appear on ALL node types that have metadata — leaf nodes and container nodes alike.
- **D-12:** Descriptions show in full (not truncated) in the overlay.
- **D-13:** Constraints (minLength, maxLength, minimum, maximum, pattern) appear ONLY in the hover overlay. No visual hint on the pill itself.
- **D-14:** The pill shape stays minimal. No inline badges, suffixes, or sub-lines added to the pill. The pill shows: type icon (or format icon / enum icon) + property name. All extra info is in the overlay.

### Claude's Discretion

- Exact amber/warm color hex for required border (should contrast with default #a0c4e8 on dark background)
- Icon designs for well-known string formats (could be unicode symbols, short text abbreviations, or SVG glyphs)
- Hover overlay positioning, sizing, background color, and text layout
- Hover overlay z-ordering (must render on top of other nodes)
- How to manage hover state in the Elm Model (which node is hovered, if any)
- NodeLayout refactoring approach for variable pill widths (format/enum icons may be wider than single-char icons)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NODE-01 | User can distinguish required properties from optional ones via a clear visual marker (not just font weight) | D-01/D-02/D-03: amber border `#e8a020` via `requiredBorder` Theme constant; `iconRect` gains `isRequired : Bool` param |
| NODE-02 | User can see string format annotations (email, date-time, uri, etc.) displayed as a badge on string nodes | D-04/D-05/D-06: new Icon variants `IEmail`, `IDateTime`, `IHostname`, `IIpv4`, `IIpv6`, `IUri`, `ICustom String`; dispatched from `Schema.String` case |
| INFO-01 | User can see schema descriptions displayed on nodes that have a `description` field | D-09/D-10/D-11/D-12: hover overlay with `desc` row; `description` already decoded in all schema types via `BaseSchema` |
| INFO-02 | User can see constraints (min/max length, min/max value, pattern) displayed on nodes | D-13: constraints in hover overlay only; `minimum`/`maximum`/`minLength`/`maxLength`/`pattern` already decoded in `StringSchema`/`IntegerSchema`/`NumberSchema` |
| INFO-03 | User can see enum values displayed on nodes that define allowed values | D-07/D-08: `IEnum` icon on pill; enum values in hover overlay; `enum` field already decoded in `StringSchema`, `IntegerSchema`, `NumberSchema`, `BooleanSchema` |
</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| elm/svg | 1.0.1 | SVG node rendering, overlay panel | Already in elm.json; the entire renderer uses it |
| elm/html | 1.0.0 | Top-level Html.Html wrapper | Already in use in `Render.Svg.view` |
| elm/core (Set, Dict) | 1.0.4 | Hover state (`Maybe String`), collapsed nodes | Already in use; `Maybe String` for `hoveredNode` follows same pattern as `collapsedNodes : Set String` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| elm/json | 1.1.2 | `Json.Decode.succeed` in `Svg.Events.stopPropagationOn` | Already used for click event decoders; same pattern for hover events |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Maybe String` for hover state | `Set String` (multi-hover) | Single hover with `Maybe` is simpler; only one overlay at a time per D-09 |
| Inline overlay in coordinate threading | Separate last-rendered overlay | Inline would break layout; separate is mandatory per D-09 |
| Browser `<title>` tooltip | Custom SVG overlay | `<title>` explicitly excluded in REQUIREMENTS.md "Out of Scope" |

**No new packages required.** All needed functionality is already in the project's elm.json.

---

## Architecture Patterns

### Recommended Project Structure

No new files required. Changes are confined to:

```
src/
├── Render/
│   ├── Svg.elm      -- Icon union extension, iconRect signature change, hover events, viewHoverOverlay
│   └── Theme.elm    -- 4 new color constants
└── Main.elm         -- hoveredNode state, HoverNode/UnhoverNode msgs, view signature update
```

An alternative of splitting overlay into `Render/Overlay.elm` is viable but the overlay function is small enough to live in `Render/Svg.elm` without making the file unmanageable.

### Pattern 1: Icon Dispatch from Schema Variant

**What:** The `Schema.String` case in `viewSchema` extracts `format` and `enum` fields, then computes the `Icon` to pass to `iconRect`. The dispatch function `iconForString` is a pure helper.

**When to use:** Any time a schema field determines node appearance.

**Example:**
```elm
-- Source: codebase pattern analysis
iconForString : Schema.StringSchema -> Icon
iconForString { format, enum } =
    case enum of
        Just _ ->
            IEnum
        Nothing ->
            case format of
                Just Schema.Email    -> IEmail
                Just Schema.DateTime -> IDateTime
                Just Schema.Hostname -> IHostname
                Just Schema.Ipv4     -> IIpv4
                Just Schema.Ipv6     -> IIpv6
                Just Schema.Uri      -> IUri
                Just (Schema.Custom s) -> ICustom s
                Nothing              -> IStr
```

### Pattern 2: Required Border via `iconRect` Parameter

**What:** Add `isRequired : Bool` as a parameter to `iconRect`. Inside, select border color based on this flag. All callers that pass through `viewProperty` already know `isRequired` (from `ObjectProperty` pattern match). Callers that are NOT properties (root schema, array items, combinators) pass `False`.

**When to use:** Every call site of `iconRect` — the boolean is explicit and explicit is better than implicit in Elm.

**Example:**
```elm
-- Modified iconRect signature
iconRect : Icon -> Maybe String -> String -> Bool -> Coordinates -> ( Svg msg, Dimensions )
iconRect icon txt weight isRequired ( x, y ) =
    let
        borderColor =
            if isRequired then Theme.requiredBorder else Theme.nodeBorder
        border =
            borderColor |> SvgA.stroke
        -- rest unchanged
    in
    ...
```

### Pattern 3: Hover State Threading

**What:** `Main.elm` holds `hoveredNode : Maybe String`. The `Render.Svg.view` function receives `hoverMsg : String -> msg`, `unhoverMsg : msg`, and `hoveredNode : Maybe String`. Each pill group `<g>` element gets `onMouseEnter`/`onMouseLeave` handlers. The overlay is rendered as the final child of the top-level `<svg>` element.

**When to use:** The hover messages travel the same path as `toggleMsg` — Main wires them, Render.Svg fires them.

**Example (view signature):**
```elm
-- Source: 07-UI-SPEC.md State Contract section
view :
    (String -> msg)   -- toggleMsg
    -> (String -> msg) -- hoverMsg
    -> msg             -- unhoverMsg
    -> Maybe String    -- hoveredNode
    -> Set String      -- collapsedNodes
    -> Definitions
    -> Schema
    -> Html.Html msg
```

**Threading approach:** To avoid adding 3 parameters through every `viewSchema`/`viewProperty`/`viewItems` call, bundle the new parameters into a record:

```elm
type alias HoverConfig msg =
    { hoverMsg  : String -> msg
    , unhoverMsg : msg
    , hoveredNode : Maybe String
    }
```

Pass `HoverConfig` alongside existing parameters, or thread it through all view functions. This is cleaner than 3 extra params at every call site.

### Pattern 4: Overlay Rendered Last

**What:** The `viewHoverOverlay` function is called in the top-level `view` after `schemaView` is computed. It receives the hover state and the full set of schema/definitions context to look up the hovered node's metadata. It returns `Svg msg` (not `(Svg msg, Dimensions)`) because it is absolutely positioned and does not participate in layout.

**When to use:** Overlay must be the final element in the SVG children list so SVG paint order puts it on top.

**Example:**
```elm
-- In view:
Svg.svg [ ... ]
    [ Svg.defs [...] [...]
    , backgroundRect
    , gridRect
    , schemaView          -- all nodes
    , overlayView         -- LAST: paints on top
    ]
```

**Finding the overlay position:** The `viewHoverOverlay` function needs the hovered node's right-edge X and top Y. These are only known during the coordinate-threaded render. Two approaches:

1. **Store dimensions in Model:** When `HoverNode path` fires, the hover handler also receives `(x, y, w, h)` from the node — requires modifying `onMouseEnter` event data.
2. **Re-derive position from path:** Not feasible without re-running layout.
3. **Pass coordinates via message:** The cleanest Elm approach — `HoverNode String Float Float Float Float` carries `(nodeRightX, nodeTopY, nodeWidth, nodeHeight)` in the message so `Main.elm` stores them alongside the path.

**Recommended:** Extend the hover message to carry node coordinates: `HoverNode String Float Float` (path, rightX, topY). Store `hoveredNodePos : Maybe (String, Float, Float)` in Model. The overlay function uses these stored coordinates to position itself.

### Anti-Patterns to Avoid

- **Changing `pillHeight = 28`:** Referenced in 9+ layout locations. Do not touch it. The amber border is a color change to the existing rect, not a size change.
- **Adding overlay to coordinate threading:** The overlay must NOT return `(Svg msg, Dimensions)` — it would shift all sibling nodes. It is absolutely positioned SVG.
- **Using browser `<title>` elements:** Explicitly excluded by REQUIREMENTS.md. Use `Svg.Events.onMouseEnter`/`onMouseLeave` only.
- **Truncating descriptions in overlay:** D-12 says full description, no truncation. Only pattern strings are truncated (at 40 chars per UI-SPEC).
- **Adding enum values to the pill:** D-08 says enum values go in the overlay only. The pill shows `IEnum` icon.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SVG z-ordering | CSS z-index, pointer-events hacks | SVG paint order (render last) | SVG has no z-index; paint order IS z-order. Render overlay as last child of `<svg>`. |
| Text wrapping in SVG | Custom word-wrap algorithm | Fixed-width estimate (6.5px/char at 11px mono) + `<tspan>` per line | SVG has no text reflow. The UI-SPEC defines 42 chars/line at overlay width. Pre-compute line breaks before rendering. |
| Hover state | Custom JS interop | `Svg.Events.onMouseEnter` / `Svg.Events.onMouseLeave` | Elm's `elm/svg` exposes these directly. No ports needed. |
| Color arithmetic | `avh4/elm-color` transformations | Hard-coded hex strings in `Render.Theme` | All colors are design tokens, not computed. Theme module already uses hex strings. |

**Key insight:** SVG rendering in Elm is pure function composition. The hover overlay is just another SVG group rendered with absolute coordinates — no special framework support needed.

---

## Common Pitfalls

### Pitfall 1: `iconRect` Call Site Cascade

**What goes wrong:** `iconRect` gains a new `isRequired : Bool` parameter. There are approximately 12 direct calls to `iconRect` in `Render.Svg.elm`. Missing even one causes a compile error in Elm, but refactoring carelessly can introduce wrong `isRequired` values at non-property call sites.

**Why it happens:** The required/optional distinction only exists at `viewProperty` level. All other call sites (root schema, array items, combinator children) are never "required" in the property sense.

**How to avoid:** Add `isRequired : Bool` as the 4th parameter. For every call site that is NOT inside `viewProperty`, pass `False`. For `viewProperty`, use `isRequired` from the `ObjectProperty` pattern match. Elm's compiler will catch all missed call sites.

**Warning signs:** Compile error listing all `iconRect` call sites — this is expected and useful. Fix each one explicitly.

### Pitfall 2: Hover Event on Nested `<g>` Groups

**What goes wrong:** SVG `onMouseEnter`/`onMouseLeave` bubble up through nested `<g>` groups. If the pill group contains child nodes (for Object/Array), hovering a child node can trigger the parent's `onMouseLeave` then re-enter, causing flicker.

**Why it happens:** SVG event bubbling. `onMouseEnter` (not `onMouseOver`) does NOT bubble — it only fires when entering the element itself. `onMouseLeave` similarly does not bubble.

**How to avoid:** Use `Svg.Events.on "mouseenter"` and `Svg.Events.on "mouseleave"` (which correspond to the non-bubbling enter/leave events), not `onMouseOver`/`onMouseOut`. In Elm's `elm/svg` 1.0.1, use `Svg.Events.onMouseOver` only if you want bubbling — prefer `mouseenter`/`mouseleave` via `Svg.Events.on`.

**Warning signs:** Overlay flickering when cursor moves within a node.

### Pitfall 3: Overlay Position Off-Screen

**What goes wrong:** The overlay panel is positioned at `nodeRightX + 8`. For nodes near the right edge of the diagram, the overlay extends beyond the SVG viewBox and is clipped.

**Why it happens:** SVG `overflow: hidden` by default on `<svg>` elements, or the viewBox clips content outside its bounds.

**How to avoid:** The UI-SPEC describes a flip strategy: if `nodeRightX + 8 + overlayWidth > diagramWidth`, render the overlay to the LEFT of the node at `nodeLeftX - overlayWidth - 8`. For Phase 7, a simpler approach is acceptable: always render to the right and rely on `overflow: visible` on the SVG (check `public/main.css` — the SVG fill the `.diagram-panel` which may clip). If clipping is observed, add `SvgA.overflow "visible"` to the outer `<svg>` element or implement the flip.

**Warning signs:** Overlay partially visible or cut off for nodes with long names near the right side.

### Pitfall 4: Text Width Estimation for Overlay Layout

**What goes wrong:** The `computeTextWidth` function uses `7.2px * charCount` at 12px monospace. The overlay uses 11px monospace for metadata text. Line-break pre-computation at 6.5px/char (per UI-SPEC) is an approximation — actual rendered widths vary by font and platform.

**Why it happens:** SVG has no text measurement API in Elm. All widths are estimated.

**How to avoid:** Use the 6.5px/char estimate consistently. Accept minor visual imprecision. Do not attempt to measure actual text width via ports/JS — it is out of scope and over-engineering for this phase.

**Warning signs:** Description text slightly overflowing the overlay boundary or wrapping one line too early.

### Pitfall 5: Schema Metadata Access in `viewHoverOverlay`

**What goes wrong:** `viewHoverOverlay` needs to access metadata (description, constraints, enum) for the hovered node. The hovered node is identified by its path string (e.g., `"root.properties.age"`), but the SVG renderer doesn't maintain a path-to-schema lookup table.

**Why it happens:** The renderer traverses the schema tree recursively. There is no index from path to schema.

**How to avoid:** Pass the full schema + definitions to `viewHoverOverlay` and re-traverse to find the node by path, OR — simpler — store the node's metadata directly in the hover message. When `HoverNode` fires, the pill's `onMouseEnter` handler already knows the schema it belongs to. Pass metadata via the message:

```elm
-- Alternative: store metadata in HoverNode message
type Msg
    = ...
    | HoverNode String NodeMeta Float Float  -- path, metadata, rightX, topY
    | UnhoverNode

type alias NodeMeta =
    { description : Maybe String
    , constraints : List (String, String)  -- e.g. [("min", "0"), ("max", "100")]
    , enumValues  : Maybe (List String)
    , baseType    : Maybe String           -- for IEnum nodes
    }
```

This avoids re-traversal entirely. The pill's render function computes `NodeMeta` at render time (it already has the schema in scope) and embeds it in the event.

---

## Code Examples

Verified patterns from codebase analysis:

### Adding `onMouseEnter`/`onMouseLeave` to a pill group

```elm
-- Source: existing Svg.Events.stopPropagationOn pattern in clickableGroup
pillGroup : (String -> msg) -> msg -> String -> Svg msg -> Svg msg
pillGroup hoverMsg unhoverMsg path svg =
    Svg.g
        [ Svg.Events.on "mouseenter"
            (Json.Decode.succeed (hoverMsg path))
        , Svg.Events.on "mouseleave"
            (Json.Decode.succeed unhoverMsg)
        ]
        [ svg ]
```

### Extending the Icon union type

```elm
-- Source: existing Icon type in Render.Svg (line 633)
type Icon
    = IList
    | IObject
    | IInt
    | IStr
    | IFloat
    | IFile
    | IBool
    | INull
    | IRef String
    -- NEW in Phase 7:
    | IEmail
    | IDateTime
    | IHostname
    | IIpv4
    | IIpv6
    | IUri
    | ICustom String
    | IEnum
```

### New Theme constants

```elm
-- Source: 07-UI-SPEC.md Color section; add to Render/Theme.elm
requiredBorder : String
requiredBorder = "#e8a020"

overlayBg : String
overlayBg = "#0f1e30"

overlayBorder : String
overlayBorder = "#3a5a7a"

overlayKeyText : String
overlayKeyText = "#8ab0d0"
```

### iconGraph dispatch for new icons

```elm
-- Extend iconGraph in Render.Svg
iconGraph : Icon -> Coordinates -> ( Svg msg, Dimensions )
iconGraph icon coords =
    case icon of
        -- existing cases unchanged...
        IEmail    -> iconGeneric coords "@"
        IDateTime -> iconGeneric coords "dt"
        IHostname -> iconGeneric coords "dns"
        IIpv4     -> iconGeneric coords "ip4"
        IIpv6     -> iconGeneric coords "ip6"
        IUri      -> iconGeneric coords "url"
        ICustom s -> iconGeneric coords (String.left 3 (String.toLower s))
        IEnum     -> iconGeneric coords "Enum"
```

### Hover overlay SVG structure (skeleton)

```elm
-- Source: 07-UI-SPEC.md Hover Overlay Design Contract
viewHoverOverlay : Maybe HoverState -> Svg msg
viewHoverOverlay maybeHover =
    case maybeHover of
        Nothing -> Svg.g [] []
        Just { x, y, meta } ->
            let
                rows = buildOverlayRows meta
                rowCount = List.length rows
                overlayHeight = 16 + rowCount * 18
                overlayWidth = 240  -- between min 160 and max 300
            in
            Svg.g []
                [ Svg.rect
                    [ SvgA.x (String.fromFloat x)
                    , SvgA.y (String.fromFloat y)
                    , SvgA.width (String.fromFloat overlayWidth)
                    , SvgA.height (String.fromFloat overlayHeight)
                    , SvgA.fill Theme.overlayBg
                    , SvgA.stroke Theme.overlayBorder
                    , SvgA.strokeWidth "1"
                    , SvgA.rx "4"
                    , SvgA.ry "4"
                    ]
                    []
                , Svg.g [] (List.indexedMap (renderRow x y) rows)
                ]
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Font weight only for required/optional | Amber border + bold for required, default border + normal for optional | Phase 7 | Both visual channels reinforce required status |
| 'S' icon for all string types | Format-specific icon (email=`@`, datetime=`dt`, etc.) | Phase 7 | Type position communicates semantic type, not structural type |
| No metadata display | Hover overlay reveals description, constraints, enum values | Phase 7 | Schema metadata accessible without leaving the diagram |

**Deprecated/outdated in this phase:**
- `viewString` calling `iconRect IStr` unconditionally — now must dispatch based on format/enum fields. Requires `viewSchema` to pass the full `StringSchema` record to a helper.

---

## Open Questions

1. **Hover coordinate storage strategy**
   - What we know: The pill's render function knows `(x, y, w, h)` from its coordinate-threading position.
   - What's unclear: Whether to pass coordinates via the `HoverNode` message (embedding at event time) or store `hoveredNode` as a path and re-derive position later.
   - Recommendation: Pass coordinates via message (`HoverNode String Float Float` carrying `rightX, topY`). This is the cleanest Elm approach — no re-traversal, no secondary lookups.

2. **Metadata passing to overlay**
   - What we know: `viewHoverOverlay` needs description, constraints, enum values.
   - What's unclear: Whether to embed `NodeMeta` in the `HoverNode` message or look up the schema by path at overlay render time.
   - Recommendation: Embed `NodeMeta` in the message. Avoids building a path-to-schema index. The `viewProperty`/`viewSchema` call site already has the schema in scope when wiring the event.

3. **`iconRect` call sites for non-property contexts**
   - What we know: `roundRect` (for combinators) does NOT use `iconRect`, so it is unaffected. `iconRect` is used in `viewSchema` for Object, Array, String, Integer, Number, Boolean, Null, Ref cases.
   - What's unclear: Whether the `isRequired` parameter at these non-property call sites is correctly `False` or if some root-level objects could semantically be required in a way not expressed by `ObjectProperty`.
   - Recommendation: Pass `False` for all non-property call sites. The `Required`/`Optional` distinction only exists within object property lists — top-level schemas have no parent to require them.

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — all changes are Elm source code edits within existing project dependencies).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | elm-explorations/test 2.0.0 |
| Config file | none (elm-test discovers tests/ directory automatically) |
| Quick run command | `elm-test` |
| Full suite command | `elm-test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NODE-01 | `iconRect` with `isRequired=True` applies amber border color | unit | `elm-test` (tests/Tests.elm) | Wave 0: add test |
| NODE-01 | `fontWeightForRequired` still returns "700" for required | unit | `elm-test` | Already covered in tests/Tests.elm |
| NODE-02 | `iconForString` dispatches Email format to `IEmail` | unit | `elm-test` | Wave 0: add test |
| NODE-02 | `iconForString` dispatches Custom format to `ICustom` | unit | `elm-test` | Wave 0: add test |
| NODE-02 | `iconForString` with no format returns `IStr` | unit | `elm-test` | Wave 0: add test |
| INFO-03 | `iconForString` with enum set returns `IEnum` | unit | `elm-test` | Wave 0: add test |
| INFO-03 | `IEnum` takes precedence over format icon | unit | `elm-test` | Wave 0: add test |

### Sampling Rate

- **Per task commit:** `elm-test`
- **Per wave merge:** `elm-test`
- **Phase gate:** Full suite green + `elm make src/Main.elm --output=/dev/null` before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/Tests.elm` — add icon dispatch tests for `iconForString`, covering all format variants and enum priority
- [ ] `tests/Tests.elm` — add test for `requiredBorderColor` helper (or `borderColorForRequired : Bool -> String`)
- [ ] No new test files needed — extend existing `tests/Tests.elm`

---

## Sources

### Primary (HIGH confidence)

- Codebase: `src/Render/Svg.elm` — full module read, all patterns verified
- Codebase: `src/Json/Schema.elm` — all schema types, `StringFormat` union, `ObjectProperty`, metadata fields verified
- Codebase: `src/Render/Theme.elm` — all existing color constants verified
- Codebase: `src/Main.elm` — Model, Msg, view wiring, `ToggleNode` pattern verified
- `.planning/phases/07-node-design-and-information-density/07-CONTEXT.md` — all decisions D-01 through D-14 read
- `.planning/phases/07-node-design-and-information-density/07-UI-SPEC.md` — full design contract read

### Secondary (MEDIUM confidence)

- `src/Json/Schema/Decode.elm` lines 179–201 — `stringFormat` function, confirmed all 6 built-in formats + Custom variant

### Tertiary (LOW confidence)

None — all findings are verified against codebase source.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; verified against elm.json and codebase
- Architecture: HIGH — all patterns derived from existing code in Render.Svg.elm; coordinate threading fully understood
- Pitfalls: HIGH — derived from direct code analysis (9+ iconRect call sites counted in source, event bubbling is documented Elm/SVG behavior)
- Icon dispatch: HIGH — StringFormat union and enum field types verified in Schema.elm
- Hover overlay: MEDIUM — implementation approach inferred from patterns; exact NodeMeta/HoverNode message design is a discretion item not yet code-verified (no prior implementation exists)

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable — Elm 0.19.1 is a frozen language; no breaking changes expected)
