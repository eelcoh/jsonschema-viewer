# Phase 3: Expand/Collapse - Research

**Researched:** 2026-04-05
**Domain:** Elm 0.19.1 interactive SVG — click-to-toggle nodes, path-key collapse state, inline $ref expansion
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Each node is identified by a schema path key (e.g., `root.properties.address.properties.street`). Path is built during rendering by appending property names and structural positions.
- **D-02:** Collapse state is stored as a `Set String` of collapsed path keys in the `Model`. Empty set = everything expanded.
- **D-03:** Collapse state resets to empty (fully expanded) on any schema re-parse — typing in textarea, selecting an example, or uploading a file. No attempt to preserve state across edits.
- **D-04:** Clicking a $ref node expands it inline — the referenced definition's full structure renders in-place. Uses existing `Dict.get ref defs` lookup.
- **D-05:** When a circular $ref is detected during inline expansion (visited-set hit), display the existing cycle indicator pill (↺ symbol from Phase 2). The cycle pill is not clickable/expandable.
- **D-06:** Expanded $ref content looks identical to regular inline schema nodes — no visual wrapper or tint.
- **D-07:** Schema renders fully expanded by default (empty collapsed set). Users collapse nodes they don't need.
- **D-08:** The entire pill-shaped node is the click target. No separate +/- icon.
- **D-09:** Pointer cursor (`cursor: pointer`) on hover for container nodes only. No hover highlight or color change.
- **D-10:** Leaf nodes (String, Integer, Number, Boolean, Null) have no click handler and no pointer cursor.

### Claude's Discretion

- Path key separator and format details (e.g., dot-separated, bracket notation)
- How to thread the path accumulator through view functions alongside existing visited set and coordinates
- SVG click handler implementation (`Svg.Events.onClick` vs wrapping in clickable `g` element)
- Transition/animation on collapse (if any — not required)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INTR-01 | User can click a node to expand or collapse its children (objects show/hide properties, arrays show/hide items) | Path-key collapse state in Model, ToggleNode Msg, Svg.Events.onClick on container pills, conditional rendering of children, inline $ref expansion with visited-set guard |

</phase_requirements>

---

## Summary

Phase 3 wires interactive expand/collapse into the existing Elm Architecture. The work is entirely internal to two files: `src/Main.elm` (Model, Msg, update) and `src/Render/Svg.elm` (view functions). No new Elm packages are needed — `Svg.Events` is already bundled with `elm/svg 1.0.1` which is in the project's `elm.json`.

The core pattern is: (1) extend `Model` with `collapsedNodes : Set String`, (2) add a `ToggleNode String` variant to `Msg`, (3) toggle the path key in `update`, (4) change `Render.Svg.view` to accept a message constructor and the collapsed set, (5) thread a `path : String` accumulator through all render functions, and (6) gate child rendering on `Set.member path collapsedNodes`. The $ref inline expansion is a conditional inside the existing `Schema.Ref` branch — when the path is NOT in the collapsed set, resolve the definition and recurse instead of rendering the label-only pill.

The existing `Set String` visited-set threading pattern (Phase 2) provides the exact mechanical precedent for threading the new collapsed set and path accumulator. The coordinate-threading pattern `(Svg msg, Dimensions)` is unaffected; the path accumulator is an additional argument, not a return value.

**Primary recommendation:** Add `path : String` as an explicit parameter to all `view*` functions, build it by appending dot-separated names and positions, and keep `collapsedNodes : Set String` in `Model` as the single source of truth.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| elm/svg | 1.0.1 | SVG element rendering and events | Already in elm.json; `Svg.Events.onClick` is in this package |
| elm/core | 1.0.4 | `Set String` for collapsed state | Already in elm.json; `Set.member`, `Set.insert`, `Set.remove` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| elm-explorations/test | 2.0.0 | Unit testing pure helpers | Test path key building, toggle logic |

No new packages required. All tools are already declared in `elm.json`.

**Installation:** None required.

**Version verification:** All packages verified against local elm package cache at `~/.elm/0.19.1/packages/`.

---

## Architecture Patterns

### Recommended Project Structure

No new files or directories needed. All changes are within:

```
src/
├── Main.elm          -- Model/Msg/update/view changes
└── Render/
    └── Svg.elm       -- view* signature changes, path threading, conditional rendering
tests/
└── RenderHelpers.elm -- new tests for path key helpers
```

### Pattern 1: Set-Based Toggle State

**What:** Store collapsed path keys in a `Set String`. Toggle = insert if absent, remove if present.

**When to use:** Any boolean per-node state where the default is "not set" (expanded). Empty set means everything expanded — no per-node initialization required.

**Example:**
```elm
-- In update, ToggleNode case:
ToggleNode pathKey ->
    let
        newCollapsed =
            if Set.member pathKey model.collapsedNodes then
                Set.remove pathKey model.collapsedNodes
            else
                Set.insert pathKey model.collapsedNodes
    in
    ( { model | collapsedNodes = newCollapsed }, Cmd.none )
```

Note: `Set` has no `toggle` function in `elm/core 1.0.4` — the pattern above is the standard approach.

### Pattern 2: Path Accumulator Threading

**What:** Pass a `path : String` argument through all `view*` functions. Build path by appending property names or positional indices at each recursive call.

**When to use:** Any time you need a unique structural address per node in a recursive tree renderer.

**Example — dot-separated, root starts as "root":**
```elm
-- Object property: path becomes "root.properties.address"
viewProperty visited defs collapsedNodes path objectProperty = ...

-- Array item at index 0: path becomes "root.items.0"
viewArrayItem visited defs collapsedNodes (path ++ ".items.0") schema = ...

-- Combinator sub-schema at index 2: path becomes "root.oneOf.2"
viewSchema visited defs collapsedNodes (path ++ ".oneOf.2") coords name weight schema = ...
```

Key rule: path segment separator is a dot (`.`). Structural positions use names that mirror JSON Pointer segment semantics (`properties`, `items`, `oneOf`, `anyOf`, `allOf`). Property name appended directly: `path ++ ".properties." ++ name`.

### Pattern 3: Concrete Msg Type in Render Module

**What:** Change `Render.Svg.view` from `Html msg` (generic) to `Html Msg` (concrete), or use a message constructor parameter.

**When to use:** When the render module needs to emit specific messages to Main's update.

**Two valid approaches:**

Option A — Pass a message constructor (more reusable, preferred for libraries):
```elm
view : (String -> msg) -> Set String -> Definitions -> Schema -> Html.Html msg
view toggleMsg collapsedNodes defs schema = ...
-- Called from Main: Render.view ToggleNode model.collapsedNodes spec.definitions spec.schema
```

Option B — Import `Main.Msg` (creates a circular import — NOT VALID in Elm).

Option A is the correct approach. The render module accepts `(String -> msg)` as a parameter and applies it in `Svg.Events.onClick (toggleMsg pathKey)`. This keeps `Render.Svg` decoupled from `Main`.

### Pattern 4: Conditional Child Rendering

**What:** At each container node, check `Set.member path collapsedNodes` before rendering children. If collapsed, render the pill only. If expanded, render pill plus children.

**When to use:** All Object, Array, OneOf, AnyOf, AllOf branches in `viewSchema`.

**Example — Object branch:**
```elm
Schema.Object { properties } ->
    let
        ( objectGraph, ( w, h ) ) =
            iconRect IObject name weight coords
                |> addOnClick (toggleMsg path)  -- or inline in iconRect variant
    in
    if Set.member path collapsedNodes then
        ( objectGraph, ( w, h ) )
    else
        let
            ( propertiesGraphs, ( pw, ph ) ) =
                viewProperties visited defs collapsedNodes path ( w + 10, y ) properties
        in
        ( Svg.g [] (objectGraph :: propertiesGraphs), ( pw, Basics.max h ph ) )
```

### Pattern 5: $ref Inline Expansion

**What:** In the `Schema.Ref` branch, when NOT collapsed, look up the definition and recursively render it inline. When collapsed (or if the definition is missing), render the label pill.

**When to use:** Only for `Schema.Ref` nodes when the definition is found in `defs`.

**Example:**
```elm
Schema.Ref { ref } ->
    let
        defName = extractRefName ref
        isCycle = isCircularRef visited ref
    in
    if isCycle then
        -- Cycle pill is never clickable (D-05)
        iconRect (IRef "*") (Just (refLabel defName True)) weight ( x, y )
    else if Set.member path collapsedNodes then
        -- Collapsed: show ref label pill with click handler to expand
        iconRect (IRef "*") (Just defName) weight ( x, y )
            |> addClickHandler (toggleMsg path)
    else
        case Dict.get ref defs of
            Nothing ->
                -- Definition not found: show label pill (not clickable — nothing to expand)
                iconRect (IRef "*") (Just defName) weight ( x, y )
            Just defSchema ->
                -- Expanded: render definition inline, add ref to visited set
                viewSchema (Set.insert ref visited) defs collapsedNodes path ( x, y ) (Just defName) weight defSchema
                    |> addClickHandlerOnPill (toggleMsg path)
```

Note: The "add click handler" mechanics require the pill `<g>` element to carry `Svg.Events.onClick`. See click handler section below.

### Pattern 6: Adding onClick to Pill Elements

**What:** `iconRect` and `roundRect` currently return `( Svg msg, Dimensions )`. The `Svg msg` is a `<g>` element. To make the pill clickable, wrap the returned `<g>` in another `<g>` that carries `Svg.Events.onClick`.

**Approach:** Add an optional message parameter to `iconRect`/`roundRect`, or create a wrapper function:

```elm
-- Wrapper approach (no change to iconRect/roundRect signature):
clickableGroup : msg -> ( Svg msg, Dimensions ) -> ( Svg msg, Dimensions )
clickableGroup msg ( svg, dims ) =
    ( Svg.g
        [ Svg.Events.onClick msg
        , SvgA.cursor "pointer"
        ]
        [ svg ]
    , dims
    )
```

Applied at each container branch in `viewSchema`:
```elm
iconRect IObject name weight coords
    |> clickableGroup (toggleMsg path)
```

This is cleaner than threading an optional `Maybe msg` into every primitive. The `clickableGroup` helper is a simple local function in `Render.Svg`.

The `cursor: pointer` attribute goes on the outer `<g>` as specified in D-09 and the UI-SPEC.

### Anti-Patterns to Avoid

- **Storing expanded nodes instead of collapsed:** The set tracks collapsed paths, not expanded ones. Empty set = everything expanded. Inverting the logic doubles the work on reset.
- **Resetting to a pre-collapsed state:** D-03 is clear — reset to `Set.empty` (fully expanded) on re-parse. Do not try to preserve state.
- **Mutating `iconRect`/`roundRect` signatures for click:** Adding `Maybe msg` to both pill primitives creates noise in the 8 call sites that never need a click handler (leaf nodes). Use `clickableGroup` wrapper instead.
- **Circular import:** Do NOT import `Main.Msg` in `Render.Svg`. Always use the constructor parameter pattern (`(String -> msg)`).
- **Making cycle pills clickable:** D-05 is explicit. When `isCycle` is true, the pill must not carry a click handler.
- **Using `List.indexedMap` positions as path segments without a stable key:** Array items should use their index (0-based integer), combinator sub-schemas should also use their index. These are stable within a given schema parse.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Toggle boolean per key | Custom map/dict solution | `Set String` with `Set.member`/`Set.insert`/`Set.remove` | 3 lines; O(log n); already in scope |
| SVG click events | Low-level `VirtualDom.on` | `Svg.Events.onClick` from `elm/svg 1.0.1` | Already available; takes a message directly |
| Unique node addresses | Hash-based ID generation | Dot-separated path accumulator built during render | Deterministic, debuggable, zero dependencies |

**Key insight:** Everything needed is already in the project's dependencies. The feature is pure Elm Architecture wiring — Model extension, Msg addition, conditional rendering.

---

## Common Pitfalls

### Pitfall 1: Elm type variable escape — `Svg msg` vs `Svg Msg`

**What goes wrong:** `viewSchema` currently returns `( Svg msg, Dimensions )` (generic `msg`). Adding `Svg.Events.onClick (toggleMsg pathKey)` forces the return type to be `( Svg msg, Dimensions )` where `msg` is constrained by `toggleMsg : String -> msg`. If `view` is called with a concrete `ToggleNode : String -> Msg`, the entire call chain unifies to `Svg Msg`. This works correctly. The error appears if you accidentally mix a generic `msg` call site with a concrete one.

**Why it happens:** Elm's type inference propagates type variables upward. Adding an event handler at a leaf forces the whole tree to a concrete type.

**How to avoid:** Change `Render.Svg.view` signature to `(String -> msg) -> Set String -> Definitions -> Schema -> Html.Html msg` and ensure `Main.elm` calls `Render.view ToggleNode model.collapsedNodes`. All internal functions use the same `msg` type variable, unified by the top-level call.

**Warning signs:** Compiler error mentioning "type variable `msg` does not match `Msg`" or "rigid type variable" in `Render/Svg.elm`.

### Pitfall 2: Path key collisions between same-named properties at different depths

**What goes wrong:** If two different schema branches both have a property named `"name"`, their path keys must differ by depth. `root.properties.name` vs `root.properties.address.properties.name`. The accumulator pattern guarantees this — each level appends its full segment.

**Why it happens:** Only if the path is built incorrectly (e.g., using just the property name rather than the full accumulated path).

**How to avoid:** Always pass the accumulated `path` down and append: `path ++ ".properties." ++ name`. Never reset to just `name`.

**Warning signs:** Collapsing one node unexpectedly collapses an unrelated node at a different depth. Success criterion #4 directly tests this.

### Pitfall 3: $ref expansion creates infinite recursion if visited-set not threaded

**What goes wrong:** When `Schema.Ref` expands inline, it calls `viewSchema` recursively with the resolved definition. If the visited set is not updated to include the current `ref` before the recursive call, a circular schema will recurse infinitely.

**Why it happens:** The visited set already exists from Phase 2 for this exact reason, but it must be passed correctly into the inline expansion call.

**How to avoid:** `viewSchema (Set.insert ref visited) defs ...` — always add the current `ref` to `visited` before the recursive expansion call. This is the same pattern as Phase 2.

**Warning signs:** Stack overflow / browser tab crash when rendering a schema with a circular `$ref`.

### Pitfall 4: Dimensions wrong after collapse

**What goes wrong:** When children are not rendered (collapsed), the parent pill's dimensions should be used as the full bounding box. If the old children dimensions are accidentally returned, layout overlaps occur.

**Why it happens:** Early return with `( objectGraph, ( w, h ) )` (pill dimensions only) must be used for the collapsed branch. If the code accidentally returns `( pw, ph )` (child dimensions from a previous computation), overlaps result.

**How to avoid:** In the collapsed branch, return `( pillSvg, pillDimensions )` directly — do not compute child positions at all. The coordinate-threading pattern means children are never laid out when their parent is collapsed.

**Warning signs:** SVG nodes visually overlap after collapsing a parent.

### Pitfall 5: Click events on SVG child elements bubble to parent

**What goes wrong:** If a nested object is inside an expanded parent, clicking a child node's pill may also fire the parent's onClick handler (event bubbling through the SVG DOM).

**Why it happens:** SVG click events bubble just like HTML click events.

**How to avoid:** Use `Svg.Events.stopPropagationOn` instead of `onClick` on container pills:
```elm
Svg.Events.stopPropagationOn "click"
    (Json.Decode.succeed ( toggleMsg pathKey, True ))
```
This stops the click from reaching ancestor containers.

**Warning signs:** Clicking a deeply nested node collapses an ancestor node unexpectedly.

---

## Code Examples

Verified patterns from `elm/svg 1.0.1` and `elm/core 1.0.4` (local package cache).

### Svg.Events.onClick — exact signature

```elm
-- Source: ~/.elm/0.19.1/packages/elm/svg/1.0.1/src/Svg/Events.elm
onClick : msg -> Attribute msg
onClick msg =
  Html.on "click" (Json.succeed msg)
```

### Svg.Events.stopPropagationOn — preferred for nested clickable nodes

```elm
-- Source: ~/.elm/0.19.1/packages/elm/svg/1.0.1/src/Svg/Events.elm
stopPropagationOn : String -> Json.Decoder (msg, Bool) -> Attribute msg
stopPropagationOn =
  Html.stopPropagationOn

-- Usage:
stopPropagationOn "click" (Json.Decode.succeed ( ToggleNode pathKey, True ))
```

### Set toggle pattern (no Set.toggle in elm/core)

```elm
-- Source: ~/.elm/0.19.1/packages/elm/core/1.0.4/src/Set.elm
-- Set.member, Set.insert, Set.remove are the primitives.

toggleInSet : comparable -> Set comparable -> Set comparable
toggleInSet key set =
    if Set.member key set then
        Set.remove key set
    else
        Set.insert key set
```

### clickableGroup wrapper

```elm
-- Local helper in Render/Svg.elm
clickableGroup : msg -> ( Svg.Svg msg, Dimensions ) -> ( Svg.Svg msg, Dimensions )
clickableGroup msg ( svg, dims ) =
    ( Svg.g
        [ Svg.Events.stopPropagationOn "click"
            (Json.Decode.succeed ( msg, True ))
        , SvgA.cursor "pointer"
        ]
        [ svg ]
    , dims
    )
```

### Render.Svg.view — updated signature

```elm
-- Before (Phase 2):
view : Definitions -> Schema -> Html.Html msg

-- After (Phase 3):
view : (String -> msg) -> Set String -> Definitions -> Schema -> Html.Html msg
view toggleMsg collapsedNodes defs schema =
    let
        ( schemaView, ( w, h ) ) =
            viewSchema Set.empty defs collapsedNodes toggleMsg "root" ( 0, 0 ) Nothing "700" schema
        vb = viewBoxString w h 20
    in
    Svg.svg [ ... ] [ schemaView ]
```

### viewSchema — updated signature

```elm
-- Existing signature:
viewSchema : Set String -> Definitions -> Coordinates -> Maybe Name -> String -> Schema -> ( Svg msg, Dimensions )

-- New signature:
viewSchema : Set String -> Definitions -> Set String -> (String -> msg) -> String -> Coordinates -> Maybe Name -> String -> Schema -> ( Svg msg, Dimensions )
--            visited      defs          collapsedNodes  toggleMsg         path     coords          name         weight  schema
```

Parameter order: keep existing `visited`, `defs`, `coords`, `name`, `weight` semantics; insert `collapsedNodes`, `toggleMsg`, `path` between `defs` and `coords` for readability.

### Main.elm — Model and Msg additions

```elm
-- Model addition:
type alias Model =
    { ...
    , collapsedNodes : Set String
    }

-- Msg addition:
type Msg
    = ...
    | ToggleNode String

-- update addition:
ToggleNode pathKey ->
    ( { model
        | collapsedNodes = toggleInSet pathKey model.collapsedNodes
      }
    , Cmd.none
    )

-- Reset on re-parse (TextareaChanged, ExampleSelected, FileContentLoaded):
, collapsedNodes = Set.empty

-- init:
, collapsedNodes = Set.empty
```

### Main.elm — view call site

```elm
-- Before:
Render.view spec.definitions spec.schema

-- After:
Render.view ToggleNode model.collapsedNodes spec.definitions spec.schema
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Render.Svg.view` returns `Html msg` (generic) | `Html msg` parameterized by `(String -> msg)` constructor | Phase 3 | Caller (Main) supplies concrete `ToggleNode`; render module stays decoupled |
| `$ref` renders label-only pill | `$ref` expands inline when not collapsed | Phase 3 | Satisfies REND-01 deferred item and INTR-01 success criterion #5 |

**Deprecated/outdated:**

- Phase 2 `Render.Svg.view : Definitions -> Schema -> Html.Html msg` — superseded by the Phase 3 signature that adds `(String -> msg)` and `Set String` parameters.

---

## Open Questions

1. **Path key for array items with no name**
   - What we know: Array items are anonymous schemas. Phase 2 renders them via `viewArrayItem` which calls `viewSchema` with `Nothing` as name.
   - What's unclear: Should array item path be `path ++ ".items"` (single items schema) or `path ++ ".items." ++ String.fromInt index` (indexed list)?
   - Recommendation: Use `path ++ ".items"` for the single `Maybe Schema` items field on `ArraySchema`. For combinator sub-schemas (OneOf/AnyOf/AllOf), use `path ++ "." ++ combinatorKey ++ "." ++ String.fromInt index` where `combinatorKey` is `"oneOf"`, `"anyOf"`, or `"allOf"`. This matches JSON Pointer semantics.

2. **Should `clickableGroup` use `stopPropagationOn` or plain `onClick`?**
   - What we know: SVG click events bubble. Nested containers could fire multiple ToggleNode messages in one click.
   - What's unclear: Whether real-world schemas in the examples actually nest containers deeply enough to trigger this.
   - Recommendation: Use `stopPropagationOn "click"` as the default for all container click handlers. The cost is zero; the bug prevention is concrete.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 3 is pure Elm code changes with no external tool dependencies beyond the existing elm compiler and elm-test runner, both confirmed available (exit 0 on `elm make`, 15 tests pass on `elm-test`).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | elm-explorations/test 2.0.0 |
| Config file | none (elm-test auto-discovers) |
| Quick run command | `elm-test` |
| Full suite command | `elm-test` |

Current suite: 15 tests, all passing, run time ~164ms.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INTR-01 | Path key builds unique address per node depth | unit | `elm-test` | ❌ Wave 0 |
| INTR-01 | Toggle inserts absent key into collapsed set | unit | `elm-test` | ❌ Wave 0 |
| INTR-01 | Toggle removes present key from collapsed set | unit | `elm-test` | ❌ Wave 0 |
| INTR-01 | Reset clears collapsed set | unit | `elm-test` | ❌ Wave 0 |
| INTR-01 | isCircularRef / visited-set guard (existing, passes) | unit | `elm-test` | ✅ |

Note: `Render.Svg.view` renders SVG — this is not unit-testable in pure Elm without a browser. The layout/click behavior is verified by compile-check plus manual browser testing against the success criteria in the CONTEXT.md.

### Sampling Rate

- **Per task commit:** `elm make src/Main.elm --output=/dev/null`
- **Per wave merge:** `elm-test`
- **Phase gate:** `elm-test` green + manual browser verification of all 5 success criteria before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/RenderHelpers.elm` — extend existing file with tests for: `toggleInSet` helper, path key construction helper (if extracted as a pure function), path key uniqueness across depths

*(Existing `RenderHelpers.elm` already covers `viewBoxString`, `extractRefName`, `isCircularRef`, `refLabel`, `fontWeightForRequired` — no new file needed, extend the existing one.)*

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 3 |
|-----------|-------------------|
| Elm 0.19.1 | No syntax or API outside 0.19.1; `Svg.Events.onClick` confirmed available |
| SVG only — no HTML for diagram | All click handlers via `Svg.Events`, not `Html.Events` |
| Client-only — no backend | No state persistence; collapse state lives in `Model` only |
| Build: `elm make src/Main.elm --output=public/elm.js --optimize` | No `Debug.log` calls added (hard blocker for `--optimize`) |
| Tests: `elm-test` | New tests go in `tests/RenderHelpers.elm` |
| Compile check: `elm make src/Main.elm --output=/dev/null` | Each task verified to compile before commit |

---

## Sources

### Primary (HIGH confidence)

- Local elm package cache `~/.elm/0.19.1/packages/elm/svg/1.0.1/src/Svg/Events.elm` — confirmed `onClick`, `stopPropagationOn` signatures
- Local elm package cache `~/.elm/0.19.1/packages/elm/core/1.0.4/src/Set.elm` — confirmed `Set.member`, `Set.insert`, `Set.remove`; no `Set.toggle` exists
- `src/Render/Svg.elm` (read directly) — confirmed existing function signatures, threading pattern, `iconRect`/`roundRect` structure
- `src/Main.elm` (read directly) — confirmed existing `Model`, `Msg`, `update`, `view` signatures and call sites
- `src/Json/Schema.elm` (read directly) — confirmed `Schema` variants, `ObjectProperty`, `Definitions`
- `elm.json` (read directly) — confirmed `elm/svg 1.0.1` and `elm/core 1.0.4` in direct dependencies
- `elm make src/Main.elm --output=/dev/null` exit 0 — codebase compiles cleanly before Phase 3 changes
- `elm-test` — 15 tests pass, ~164ms

### Secondary (MEDIUM confidence)

- `.planning/phases/03-expand-collapse/03-CONTEXT.md` — locked decisions D-01 through D-10
- `.planning/phases/03-expand-collapse/03-UI-SPEC.md` — pointer cursor placement, click target spec, component inventory

### Tertiary (LOW confidence)

None.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages verified in local elm cache and elm.json
- Architecture: HIGH — all patterns derived from reading actual source files
- Pitfalls: HIGH — Elm type system, SVG event bubbling, and visited-set requirements are verified facts, not guesses

**Research date:** 2026-04-05
**Valid until:** Stable — Elm 0.19.1 is no longer receiving breaking changes; elm/svg 1.0.1 API is fixed.
