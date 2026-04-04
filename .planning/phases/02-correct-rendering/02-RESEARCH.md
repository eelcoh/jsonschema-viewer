# Phase 2: Correct Rendering - Research

**Researched:** 2026-04-04
**Domain:** Elm 0.19.1 SVG rendering — coordinate-threading pattern, $ref guard, dynamic viewBox
**Confidence:** HIGH

## Summary

Phase 2 makes three targeted changes to `src/Render/Svg.elm`: (1) render $ref nodes with correct definition names and distinct styling, (2) dynamically compute the SVG viewBox from the diagram's total extent, and (3) distinguish required from optional properties by font weight. All three changes are purely within `Render.Svg.elm` — no new packages are needed. The coordinate-threading pattern already returns `(Svg msg, Dimensions)` so the total extent is already computed; it just isn't used for the viewBox.

The only design decision still open is how to thread a visited-set for the circular $ref guard. The CONTEXT.md locked decision D-06/D-07 calls for a `Set String` of visited `$ref` keys. Because `viewSchema` already threads `Definitions` as an explicit parameter, the same threading approach applies to a `Set String`. No architecture changes are needed — this is a parameter addition and case-expression change.

**Primary recommendation:** Add a `Set String` visited parameter to `viewSchema` (and all callers), use it to detect cycles, and return a cycle node with "↺" on detection. Compute the viewBox from the `Dimensions` returned by the top-level `viewSchema` call in `view`. Apply `fontWeight "700"` for `Required` and remove it for `Optional` in `viewProperty`.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** $ref nodes render as labeled nodes showing the definition name with a distinct visual style (not inline expansion). The current `roundRect` label approach is kept but improved with the definition name.
- **D-02:** Inline expansion of $ref content is deferred to Phase 3. Phase 2 ensures the ref label is correct and visually distinct.
- **D-03:** Phase 2 success criterion #1 must be updated: "$ref nodes display the referenced definition name and are visually distinct" (replacing the original "renders fields inline" wording).
- **D-04:** Required property names render in bold (`fontWeight "700"`), optional property names render in normal weight. Uses the existing bold pattern from `viewNameGraph`.
- **D-05:** No color or icon difference — bold/normal weight is sufficient distinction.
- **D-06:** A visited-set pattern guards against infinite recursion when resolving $ref chains.
- **D-07:** When a circular $ref is detected, display the $ref node with its definition name plus a cycle indicator symbol (↺) to communicate the circular reference.
- **D-08:** The SVG `viewBox` is calculated dynamically from the total diagram dimensions returned by the coordinate-threading pattern, plus padding.
- **D-09:** The SVG element uses `width`/`height` of 100% of its container. Small schemas fit tightly, large schemas expand to show everything.
- **D-10:** Replaces the current hardcoded `520x520` viewBox.

### Claude's Discretion

- Exact padding amount for the auto-fit viewBox
- Implementation details of the visited-set guard (Set vs Dict, threading approach)
- Specific ↺ symbol rendering (SVG text or Unicode character)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REND-01 | `$ref` references are resolved and rendered inline with the referenced schema content (with circular reference guard) | Locked to D-01/D-02: label-only rendering with definition name; guard via visited-set (D-06/D-07). Full inline expansion deferred to Phase 3. |
| REND-02 | SVG viewport dynamically scales to fit the rendered schema diagram | Coordinate-threading pattern already returns total `Dimensions`; feed into `viewBox` string in `view`. |
| REND-03 | Required properties are visually distinct from optional properties | `viewProperty` already pattern-matches `Required`/`Optional`; add `fontWeight "700"` to Required branch only. |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| elm/svg | 1.0.1 | SVG element and attribute construction | Already in project; no alternative |
| elm/core Set | built-in | Visited-set for circular $ref guard | `Set String` is the idiomatic Elm choice for membership tests; no import needed beyond `Set` |
| elm/core | 1.0.4 | String, Dict, Maybe, Basics | Already in project |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| avh4/elm-color | 1.0.0 | Color constants (`darkClr`, `lightClr`) | Already used for all node colors |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Set String` visited set | `Dict String ()` | No practical difference; `Set` is more expressive, use it |
| Unicode ↺ in SVG `text_` | SVG path arrow | Unicode is simpler and renders in monospace; no SVG path needed |
| `width "100%" height "100%"` | `width "800" height "600"` | 100% fills container and works with dynamic viewBox — correct choice per D-09 |

**Installation:** No new packages needed. All required libraries are already in `elm.json`.

---

## Architecture Patterns

### Recommended Project Structure

No structural changes. All changes are within:

```
src/
└── Render/
    └── Svg.elm      -- all three fixes live here
```

`Json/Schema.elm` and `Json/Schema/Decode.elm` are read-only for this phase.

### Pattern 1: Coordinate-Threading

**What:** Every view function returns `(Svg msg, Dimensions)` where `Dimensions = (Float, Float)` is `(maxX, maxY)` reached by the subtree. Callers use the returned dimensions to position siblings.

**When to use:** Already the established pattern. Do not deviate.

**Current entry point:**
```elm
-- Render/Svg.elm line 33-44
view : Definitions -> Schema -> Html.Html msg
view defs schema =
    let
        schemaView =
            Tuple.first <| viewSchema defs ( 0, 0 ) Nothing schema
    in
    Svg.svg
        [ SvgA.width "520"
        , SvgA.height "520"
        , SvgA.viewBox "0 0 520 520"
        ]
        [ schemaView ]
```

**After fix (REND-02):** Capture both tuple elements and use dims to build viewBox:
```elm
view : Definitions -> Schema -> Html.Html msg
view defs schema =
    let
        ( schemaView, ( w, h ) ) =
            viewSchema Set.empty defs ( 0, 0 ) Nothing schema

        padding =
            20

        vb =
            "0 0 "
                ++ String.fromFloat (w + padding)
                ++ " "
                ++ String.fromFloat (h + padding)
    in
    Svg.svg
        [ SvgA.width "100%"
        , SvgA.height "100%"
        , SvgA.viewBox vb
        ]
        [ schemaView ]
```

### Pattern 2: Visited-Set Threading for Circular $ref Guard

**What:** Pass a `Set String` of already-visited `$ref` keys through `viewSchema`. Before following a `$ref`, check membership. On hit, render a cycle node instead of recursing.

**When to use:** Required for REND-01 per D-06/D-07. Thread `visited : Set String` as the first new parameter to `viewSchema`.

**Signature change:**
```elm
-- Before
viewSchema : Definitions -> Coordinates -> Maybe Name -> Schema -> ( Svg msg, Dimensions )

-- After
viewSchema : Set String -> Definitions -> Coordinates -> Maybe Name -> Schema -> ( Svg msg, Dimensions )
```

All call sites must pass the set. Internal recursive calls pass the set. The Ref branch adds `ref` to the set before any future expansion. In Phase 2, $ref nodes do not recursively expand — but the guard must still be in place for correctness and to unblock Phase 3.

**Ref branch implementation:**
```elm
Schema.Ref { title, ref } ->
    let
        refName =
            String.dropLeft 14 ref   -- drops "#/definitions/"

        isCycle =
            Set.member ref visited

        label =
            if isCycle then
                refName ++ " ↺"
            else
                refName
    in
    iconRect (IRef label) name ( x, y )
    -- Note: no expansion in Phase 2 per D-01/D-02
    -- visited set updated here is prep for Phase 3 inline expansion
```

The existing `Dict.get ref defs` lookup and commented-out expansion code in the Ref branch can be removed or left commented. Phase 3 will implement it properly using the visited set.

### Pattern 3: Required vs Optional Font Weight

**What:** `viewProperty` already pattern-matches `Required` vs `Optional` to extract `name` and `property`. The current code treats both identically. The fix adds a boolean that flows into the name rendering.

**Current code (Render/Svg.elm line 359-372):**
```elm
viewProperty defs coords objectProperty =
    let
        ( name, property ) =
            case objectProperty of
                Schema.Required name_ property_ ->
                    ( name_, property_ )

                Schema.Optional name_ property_ ->
                    ( name_, property_ )

        ( schemaGraph, newCoords ) =
            viewSchema defs coords (Just name) property
    in
    ( Svg.g [] [ schemaGraph ], newCoords )
```

**The problem:** `viewNameGraph` always renders with `fontWeight "700"` (bold). Required and optional names both pass through `viewNameGraph` via `iconRect`. To distinguish them, `viewNameGraph` needs a weight parameter, or a separate `viewNameGraphNormal` helper is used.

**Recommended approach:** Add a `FontWeight` parameter to `viewNameGraph` (or use a `Bool`):

```elm
-- Option A: pass font weight string
viewNameGraph : String -> Coordinates -> String -> ( Svg msg, Dimensions )
viewNameGraph fontWeight ( x, y ) name =
    -- ... same as before but use fontWeight param instead of "700"

-- viewProperty calls:
Schema.Required name_ property_ ->
    viewSchema visited defs coords (Just ( name_, "700" )) property_

Schema.Optional name_ property_ ->
    viewSchema visited defs coords (Just ( name_, "400" )) property_
```

**Simpler option (recommended):** Keep `viewNameGraph` as-is (always bold). Create `viewNameGraphNormal` that is identical but uses `fontWeight "400"`. Then `iconRect` receives a `Bool` or a separate entry point:

```elm
-- Even simpler: add isRequired Bool to viewProperty, thread to iconRect
viewProperty : Set String -> Definitions -> Coordinates -> Schema.ObjectProperty -> ( Svg msg, Dimensions )
viewProperty visited defs coords objectProperty =
    let
        ( name, property, isRequired ) =
            case objectProperty of
                Schema.Required name_ property_ ->
                    ( name_, property_, True )

                Schema.Optional name_ property_ ->
                    ( name_, property_, False )

        ( schemaGraph, newCoords ) =
            viewSchemaWithWeight visited defs coords (Just name) isRequired property
    in
    ( Svg.g [] [ schemaGraph ], newCoords )
```

The cleanest approach that minimizes churn: add a `weight` parameter only to `viewNameGraph`, change `iconRect` to accept it, change `viewProperty` to pass the correct weight. The weight does not propagate to nested schemas — only the immediate name label is affected.

### Anti-Patterns to Avoid

- **Storing visited-set in Model:** The visited-set is purely a render-time concern. Do not put it in `Model` or `Msg`. Thread it as a function parameter.
- **Expanding $ref in Phase 2:** D-02 explicitly defers this. The Ref branch must not recursively call `viewSchema` on the resolved definition in Phase 2.
- **Using `elm/set` module path:** It's `Set` from `elm/core`, imported as `import Set exposing (Set)`. No package install needed.
- **Hardcoded viewBox numbers in viewBox string:** Use `String.fromFloat` on the computed dimensions, not string literals.
- **Removing the `Tuple.first` call before adding `Dimensions` capture:** Remember to switch from `Tuple.first <| viewSchema ...` to full destructuring `( svg, ( w, h ) ) = viewSchema ...`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cycle detection in graph traversal | Custom counter/flag | `Set String` membership test | O(log n), standard Elm idiom, zero risk of off-by-one |
| Dynamic SVG sizing | JS port or ResizeObserver | Compute from `Dimensions` returned by coordinate-threading | Dimensions are already computed — the viewBox is arithmetic |
| Bold/normal weight toggle | Second complete copy of node rendering | Single `viewNameGraph` with weight param | Two functions diverge over time; one param is safe |

**Key insight:** This phase requires zero new packages and zero new architectural patterns. Every problem is solved by threading an additional parameter or using an already-computed value.

---

## Common Pitfalls

### Pitfall 1: Signature Change Cascade

**What goes wrong:** Adding `visited : Set String` to `viewSchema` breaks every call site. Elm's compiler will enumerate all of them but they're not always obvious.

**Why it happens:** `viewSchema` is called from: `view`, `viewAnonymousSchema`, `viewProperty`, `viewArrayItem`, `viewMulti`, `viewItems_` (via `viewArrayItem`), and the `Schema.Array` and `Schema.Object` branches of `viewSchema` itself.

**How to avoid:** Change `viewSchema`'s signature first. Let the compiler enumerate all errors. Fix them in order. Pass `Set.empty` at `view` (the external entry point). Pass `visited` unchanged at all recursive calls. Pass `Set.insert ref visited` only when following a $ref (which Phase 2 does not do yet, but prepare the parameter).

**Warning signs:** Compiler error count above 8 for this change — look for missed call sites inside let-bindings in `viewProperties` and `viewItems`.

### Pitfall 2: viewBox String Format

**What goes wrong:** SVG `viewBox` attribute must be `"minX minY width height"` — four space-separated numbers. It is NOT `"x y"`.

**Why it happens:** Confusing `viewBox` (four values) with `x`/`y`/`width`/`height` attributes.

**How to avoid:** Always use: `"0 0 " ++ String.fromFloat totalWidth ++ " " ++ String.fromFloat totalHeight`.

**Warning signs:** SVG renders but content is clipped or scaled incorrectly.

### Pitfall 3: Dimensions Are (maxX, maxY), Not (width, height)

**What goes wrong:** The coordinate-threading pattern returns absolute `(x, y)` positions, not sizes. The top-level schema starts at `(0, 0)`, so the returned `Dimensions` ARE `(width, height)`. But if the starting position ever changes (e.g., adding a margin offset), the returned dimensions must be adjusted.

**Why it happens:** `Dimensions = (Float, Float)` is used for two different things in the code: the absolute max coordinate of a subtree, and the width/height of a single node (as in `roundRect` returning `( rectWidth + x, 28 + y )`).

**How to avoid:** Keep the entry call in `view` at `( 0, 0 )` so dimensions equal extents. If padding is added at the viewBox level, add it there, not by offsetting the initial coordinates.

**Warning signs:** Content is cut off at the right or bottom, or there is unexpected extra whitespace.

### Pitfall 4: IRef Icon Text Width

**What goes wrong:** `IRef s` maps to `iconGeneric coords ("*" ++ s)`. If `s` is the full definition name (e.g., "veggie"), the icon area will be as wide as "*veggie", pushing the separator and name label far right.

**Why it happens:** The existing `IRef` pattern was designed for a short label. With real definition names, the icon section becomes the dominant width.

**How to avoid:** Per D-01, the $ref node shows the definition name in the name section (after the separator), not the icon section. The icon section should stay compact — either just `"*"` or a short marker like `"ref"`. The `refName` goes in the `name` argument to `iconRect`, not in the `IRef` variant string.

**Warning signs:** $ref node is much wider than other nodes; definition name appears doubled (once in icon, once in name label).

### Pitfall 5: fontWeight on nested schemas

**What goes wrong:** Making `isRequired` propagate transitively — all children of a required property become bold.

**Why it happens:** If `isRequired` is passed into `viewSchema` as a parameter and applied to all name renders within that schema, nested properties inherit the weight.

**How to avoid:** The weight applies ONLY to the immediate property name in `viewProperty`. The schema rendered to the right of the name (the type node, e.g., the object pill) uses its own default rendering. Do not thread `isRequired` into `viewSchema` itself.

**Warning signs:** Grandchild property names are bold when they should be normal weight.

---

## Code Examples

Verified patterns from existing source:

### Dynamic viewBox Construction
```elm
-- Source: src/Render/Svg.elm lines 36-44 (current, to be replaced)
-- Pattern: capture both elements of the (Svg, Dimensions) tuple
let
    ( schemaView, ( w, h ) ) =
        viewSchema Set.empty defs ( 0, 0 ) Nothing schema

    padding = 20

    vb =
        "0 0 "
            ++ String.fromFloat (w + padding)
            ++ " "
            ++ String.fromFloat (h + padding)
in
Svg.svg
    [ SvgA.width "100%"
    , SvgA.height "100%"
    , SvgA.viewBox vb
    ]
    [ schemaView ]
```

### Set Import Pattern for Visited-Set
```elm
-- Add to module imports in Render/Svg.elm
import Set exposing (Set)

-- viewSchema new signature
viewSchema : Set String -> Definitions -> Coordinates -> Maybe Name -> Schema -> ( Svg msg, Dimensions )
viewSchema visited defs (( x, y ) as coords) name schema =
    case schema of
        -- ...
        Schema.Ref { title, ref } ->
            let
                refName = String.dropLeft 14 ref
                isCycle = Set.member ref visited
                label = if isCycle then refName ++ " ↺" else refName
                -- visited_ = Set.insert ref visited  -- ready for Phase 3
            in
            iconRect (IRef label) name ( x, y )
        -- ...
```

### Required vs Optional in viewProperty
```elm
-- Source: src/Render/Svg.elm line 359 (current pattern to modify)
viewProperty : Set String -> Definitions -> Coordinates -> Schema.ObjectProperty -> ( Svg msg, Dimensions )
viewProperty visited defs coords objectProperty =
    case objectProperty of
        Schema.Required name_ property_ ->
            let
                ( schemaGraph, newCoords ) =
                    viewSchema visited defs coords (Just name_) property_
            in
            -- name_ renders bold because viewNameGraph uses fontWeight "700"
            ( Svg.g [] [ schemaGraph ], newCoords )

        Schema.Optional name_ property_ ->
            let
                ( schemaGraph, newCoords ) =
                    viewSchemaOptional visited defs coords (Just name_) property_
                    -- or: pass weight flag through to iconRect -> viewNameGraph
            in
            ( Svg.g [] [ schemaGraph ], newCoords )
```

### Existing fontWeight "700" Pattern
```elm
-- Source: src/Render/Svg.elm lines 529-568 (viewNameGraph)
-- Currently ALL names use fontWeight "700"
-- Phase 2 change: add fontWeight parameter
viewNameGraph : String -> Coordinates -> String -> ( Svg msg, Dimensions )
viewNameGraph weight ( x, y ) name =
    let
        attrs =
            [ SvgA.x (String.fromFloat mt)
            , SvgA.y (String.fromFloat tt)
            , fg
            , SvgA.fontFamily "Monospace"
            , SvgA.fontSize "12"
            , SvgA.fontWeight weight       -- "700" for required, "400" for optional
            , SvgA.dominantBaseline "middle"
            , SvgA.cursor "pointer"
            ]
    in
    -- ...
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded viewBox "0 0 520 520" | Dynamic from computed Dimensions | Phase 2 | Schemas of any size render correctly |
| $ref renders with `roundRect ref` (full key) | $ref renders `iconRect` with definition name only | Phase 2 | Cleaner display; full `#/definitions/` prefix dropped |
| No cycle guard | Set-based visited tracking | Phase 2 | Infinite recursion impossible |
| All property names bold | Required bold, Optional normal weight | Phase 2 | Visual distinction per D-04 |

**Deprecated/outdated:**
- `roundRect ref ( w + 10, y )` in the Ref branch: the full `ref` key (with `#/definitions/` prefix) was passed as the label. Replace with `roundRect refName` or eliminate entirely (Phase 2 shows the iconRect, not a secondary roundRect).

---

## Open Questions

1. **Should `viewNameGraph` signature change affect `iconRect`?**
   - What we know: `iconRect` calls `viewNameGraph` as `Maybe.map (viewNameGraph ( separatorW + space, y )) txt`. Changing `viewNameGraph` to take a weight first changes this call.
   - What's unclear: whether to thread weight through `iconRect` as a new parameter, or create a separate `iconRectOptional` helper.
   - Recommendation: Add `weight : String` as a parameter to both `viewNameGraph` and `iconRect`. Update all callers: most pass `"700"` (existing behavior), only `viewProperty`'s Optional branch passes `"400"`. Minimal churn.

2. **Exact padding for the auto-fit viewBox**
   - What we know: 20px is a reasonable starting value. The current 520x520 gives no explicit padding.
   - What's unclear: Whether the visual result needs more padding on different schema sizes.
   - Recommendation: Use 20px padding. This is a discretion item per CONTEXT.md.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| elm | Compilation | Yes | 0.19.1 | - |
| elm-test | Test suite | Yes | 0.19.1-revision17 | - |

No missing dependencies. Phase 2 requires no new packages.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | elm-explorations/test 1.0.0 |
| Config file | none (elm-test auto-discovers `tests/`) |
| Quick run command | `elm-test` |
| Full suite command | `elm-test` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REND-01 | $ref node displays definition name (not raw ref key) | unit | `elm-test` | Wave 0 |
| REND-01 | Circular $ref detected via visited-set, renders ↺ | unit | `elm-test` | Wave 0 |
| REND-02 | viewBox string contains computed width from Dimensions | unit | `elm-test` | Wave 0 |
| REND-03 | Required property name uses fontWeight "700" | unit | `elm-test` | Wave 0 |
| REND-03 | Optional property name uses fontWeight "400" (or "normal") | unit | `elm-test` | Wave 0 |

Note: `Render.Svg` produces `Html.Html msg` / `Svg msg` values. Unit testing SVG output in elm-explorations/test requires inspecting the virtual DOM representation. Elm does not expose a DOM query API in tests — the standard approach is to test the pure helper functions (e.g., the viewBox string construction, the `refName` extraction, the cycle detection logic) as isolated pure functions, and rely on browser/visual review for final SVG shape. Tests that call `view` and inspect the returned `Html` structure are valid but fragile; focus tests on the pure logic.

### Sampling Rate
- **Per task commit:** `elm-test`
- **Per wave merge:** `elm-test` + `elm make src/Main.elm --output=/dev/null`
- **Phase gate:** `elm-test` green + compile check green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/Tests.elm` currently contains a deliberately failing test (`Expect.fail "failed as expected!"`). This must be fixed or removed before the test suite can be a gate signal.
- [ ] Tests for `refName` extraction (pure String function — easy unit test)
- [ ] Tests for cycle detection (Set.member logic — easy unit test)
- [ ] Tests for viewBox string construction (pure arithmetic — easy unit test)
- [ ] Tests for font weight selection by Required/Optional (pure logic — easy unit test)

---

## Project Constraints (from CLAUDE.md)

- Elm 0.19.1 — no newer syntax or packages
- Build: `elm make src/Main.elm --output=public/elm.js --optimize && cp src/main.css public/main.css`
- Tests: `elm-test`
- Compile check: `elm make src/Main.elm --output=/dev/null`
- `elm/svg` is the only SVG library — no external SVG frameworks
- Client-only — no backend, no ports required for this phase
- `--optimize` flag is used in production build — no `Debug.*` calls may exist in `Render.Svg`
- Build output to `public/elm.js` and `public/main.css` (gitignored)

---

## Sources

### Primary (HIGH confidence)
- Direct read of `src/Render/Svg.elm` — full implementation of coordinate-threading pattern, iconRect, viewNameGraph, viewProperty, Ref branch
- Direct read of `src/Json/Schema.elm` — ObjectProperty union type (Required/Optional), Definitions, RefSchema
- Direct read of `src/Json/Schema/Decode.elm` — $ref stored with `#/definitions/` prefix (line 26: `Tuple.mapFirst ((++) "#/definitions/")`)
- Direct read of `elm.json` — confirmed packages: elm/svg 1.0.1, elm/core 1.0.4, elm-explorations/test 1.0.0
- Direct read of `.planning/phases/02-correct-rendering/02-CONTEXT.md` — locked decisions D-01 through D-10

### Secondary (MEDIUM confidence)
- elm/svg package: `SvgA.viewBox` takes a string in "minX minY width height" format — standard SVG attribute, well-established

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified from elm.json and source
- Architecture: HIGH — patterns read directly from existing source
- Pitfalls: HIGH — derived from direct code analysis (IRef width issue, Dimensions semantics, signature cascade)
- Test infrastructure: HIGH — elm-test 0.19.1-revision17 confirmed present

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (stable ecosystem — Elm 0.19.1 is not changing)
