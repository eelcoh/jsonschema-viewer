# Domain Pitfalls

**Domain:** Interactive SVG diagram viewer for JSON Schema in Elm 0.19.1
**Researched:** 2026-04-03
**Confidence:** HIGH (derived from direct codebase analysis + Elm 0.19.1 language constraints)

---

## Critical Pitfalls

Mistakes that cause rewrites or major architectural changes.

---

### Pitfall 1: Debug.log Calls Block Production Builds

**What goes wrong:** `elm make --optimize` (used by `elm-app build`) rejects any file containing `Debug.log` or `Debug.todo` calls with a hard compiler error. The current codebase has three `Debug.log` calls in `Render/Svg.elm` (`iconGeneric`, `color`, and `viewSchema`). Adding more during development makes production builds impossible until they are all removed.

**Why it happens:** Elm's `--optimize` flag enforces a clean separation between development helpers and production code. It is not a warning — it is a compiler error that halts the build entirely.

**Consequences:** CI builds fail. Production deployments are blocked. Finding all `Debug.log` calls under time pressure is error-prone.

**Prevention:** Establish a policy at the start of each phase: never commit `Debug.log` calls to `src/`. Use a pre-commit hook or CI step. Alternatively, centralize debug output in a dedicated `Debug.elm` module that is swapped out at build time. Address the three existing calls in Phase 1 before adding any interactivity.

**Detection:** Run `elm make src/Main.elm --output=/dev/null --optimize` in CI. The compiler will name every offending file and line number.

**Affects phases:** Phase 1 (cleanup before adding interactivity), all subsequent phases.

---

### Pitfall 2: Circular $ref Causes Infinite Recursion at Render Time

**What goes wrong:** JSON Schema permits circular references — a schema can `$ref` a definition that eventually `$ref`s back to itself. The current `Render.Svg` code avoids this by rendering `$ref` nodes as stub labels instead of expanding them inline. When inline `$ref` expansion is implemented (required for a usable viewer), naively passing `defs` and calling `viewSchema` recursively on the resolved schema will loop until the browser stack overflows.

**Why it happens:** The `Schema` type has a `Ref { ref : String }` variant. Resolving it via `Dict.get ref defs` returns a `Schema` which may itself contain a `Ref` pointing back to the original key. There is no cycle detection in the current render path. The commented-out code in `Render.Svg` (`-- |> Maybe.map (viewSchema defs ( w + 10, y ) Nothing)`) shows a prior attempt that was abandoned, likely for this reason.

**Consequences:** Browser freeze or crash on any schema with self-referential definitions (common in real-world OpenAPI specs, e.g. a `Pet` that references `Category` which is referenced elsewhere).

**Prevention:** Track a `Set String` of `$ref` keys currently in the render call stack. Pass it as a parameter alongside `defs`. When a `Ref` is encountered, check whether the key is already in the visited set before expanding. If visited, render a stub node. If not visited, add the key to the set and recurse.

```elm
viewSchema : Definitions -> Set String -> Coordinates -> Maybe Name -> Schema -> ( Svg msg, Dimensions )
viewSchema defs visited coords name schema =
    case schema of
        Schema.Ref { ref } ->
            if Set.member ref visited then
                renderStub ref coords  -- break the cycle
            else
                case Dict.get ref defs of
                    Nothing -> renderStub ref coords
                    Just resolved ->
                        viewSchema defs (Set.insert ref visited) coords name resolved
        ...
```

**Detection:** Load the Petstore Swagger schema already present in `Main.elm`. The `Pet` -> `Category` -> `Tag` chain is acyclic but any schema where `A.$ref -> B` and `B.$ref -> A` will trigger infinite recursion immediately.

**Affects phases:** Phase implementing $ref inline expansion.

---

### Pitfall 3: Node Identity for Expand/Collapse State Requires Stable Path Keys

**What goes wrong:** Expand/collapse state requires a `Dict` or `Set` keyed on some node identifier. The obvious choice — property name or schema title — is not unique. A schema can have `name` as a property on multiple nested objects. Using only the local name causes toggling one node to visually toggle all nodes with the same name.

**Why it happens:** JSON Schema properties are named locally within their parent object. The same name can appear at any depth. The `Schema` type stores property names as `String` in `ObjectProperty (Required String Schema | Optional String Schema)` — there is no globally unique ID on any node.

**Consequences:** Clicking to collapse `address.city` also collapses `billing.city` and `shipping.city`. The UI becomes unpredictable. This is difficult to fix retroactively if state management is already wired throughout the renderer.

**Prevention:** Define a stable path-based node key before writing any expand/collapse logic. Represent node paths as `List String` (e.g. `["properties", "address", "properties", "city"]`) and derive a `String` key by joining with a separator unlikely to appear in property names (e.g. `"\u0000"`). Thread this path through every `viewSchema` / `viewProperty` call from the root.

**Detection:** Create a test schema with the same property name at two different depths. Clicking either node must not affect the other.

**Affects phases:** Phase adding expand/collapse state — must be designed in from the start of that phase, not retrofitted.

---

### Pitfall 4: The Coordinate-Threading Pattern Breaks When Layout Depends on Collapsed State

**What goes wrong:** The current `Render.Svg` computes layout by threading `(x, y)` coordinates through recursive calls, with each node returning its bounding `Dimensions` so the next sibling can be placed below it. Collapsed nodes must contribute zero height for their children. If the collapsed check is added inconsistently — only in some branches, or only to the children but not to the returned dimensions — sibling nodes overlap or leave blank gaps.

**Why it happens:** The pattern `( Svg msg, Dimensions )` returns actual rendered dimensions. A collapsed node renders nothing for its children but still returns the full expanded bounding box if the dimensions calculation is not also conditioned on collapse state. This is a two-part update (render path and dimension path) that must be synchronized.

**Consequences:** Nodes overlap (collapsed node height was returned as full height) or there are blank regions in the SVG (expanded node height was returned as zero). The diagram looks broken.

**Prevention:** When a node is collapsed, its `viewSchema`/`viewProperties` call must return `( emptyGroup, ( x, y + pillHeight ) )` — only the height of the header pill, not the children. Create a helper:

```elm
childrenOrCollapsed : Bool -> (() -> ( Svg msg, Dimensions )) -> Coordinates -> ( Svg msg, Dimensions )
childrenOrCollapsed isExpanded renderChildren ( x, y ) =
    if isExpanded then
        renderChildren ()
    else
        ( Svg.g [] [], ( x, y + pillHeight ) )
```

Use this helper consistently in every branch that renders children (Object properties, Array items, OneOf/AnyOf/AllOf sub-schemas).

**Detection:** Toggle a collapsed node and verify the next sibling's y-coordinate shifts up by exactly `pillHeight` (28px) from the collapsed node's origin.

**Affects phases:** Phase adding expand/collapse — must be treated as a layout refactor, not just a state addition.

---

### Pitfall 5: Browser.sandbox Cannot Receive User Input — Migration Must Be Done Correctly

**What goes wrong:** `Browser.sandbox` has no `init` flags and no subscriptions. Adding a text area for schema paste requires `Browser.element` (flags or ports for file input) and a proper `Cmd`/`Sub` architecture. A common mistake is to incrementally add `Cmd.none` returns to `update` while still using `sandbox`, which the Elm compiler will reject with a type error pointing at `main`, not at the actual problem.

**Why it happens:** `Browser.sandbox` has type `{ init : model, update : msg -> model -> model, view : model -> Html msg }`. `Browser.element` has type `{ init : flags -> ( model, Cmd msg ), update : msg -> model -> ( model, Cmd msg ), view : model -> Html msg, subscriptions : model -> Sub msg }`. Every `update` branch must return a tuple, and `init` must return a tuple. Forgetting one branch causes a type mismatch that can be confusing to locate.

**Consequences:** Compiler errors cascade. If the migration is done in the middle of another feature, it becomes unclear which error is from the migration and which is from the new feature.

**Prevention:** Do the `Browser.sandbox` to `Browser.element` migration as its own isolated commit before starting user-input features. Steps: (1) change `main` to use `Browser.element`, (2) update `init` to `flags -> ( Model, Cmd Msg )`, (3) update every `update` branch to return `( model, Cmd.none )`, (4) add `subscriptions = \_ -> Sub.none`, (5) compile and confirm green before touching anything else.

**Detection:** The codebase currently has `main = Browser.sandbox { ... }` in `Main.elm`. The migration will cause type errors in `update` that must be resolved before proceeding.

**Affects phases:** Phase 1 (must be done before user input can be added).

---

## Moderate Pitfalls

---

### Pitfall 6: SVG Click Events Require stopPropagation or Children Capture Parent Clicks

**What goes wrong:** In SVG, `<g>` elements containing child `<rect>` and `<text>` elements pass click events upward through the DOM. If a parent `<g>` has an `onClick` handler and child elements also have `onClick` handlers, clicking a child fires both handlers. In the context of expand/collapse, clicking a property pill to expand it also fires the parent object's collapse handler.

**Why it happens:** SVG event bubbling follows the same rules as HTML. Elm's `Svg.Events.onClick` maps to a standard DOM event listener. Without `stopPropagation`, events bubble up through the SVG element tree.

**Consequences:** Clicking a nested node toggles both the node and its parent. Interaction feels broken and unpredictable.

**Prevention:** Use `Svg.Events.stopPropagationOn "click"` from `elm/svg` (or `Html.Events.stopPropagationOn` which also works in SVG context) for any clickable SVG group that should not propagate. Apply this to every interactive node pill.

```elm
import Html.Events exposing (stopPropagationOn)
import Json.Decode as Decode

onClickStopPropagation : msg -> Svg.Attribute msg
onClickStopPropagation msg =
    stopPropagationOn "click" (Decode.succeed ( msg, True ))
```

**Detection:** Nest two expandable objects and click the inner one. If the outer one also toggles, propagation is not being stopped.

**Affects phases:** Phase adding expand/collapse click handlers.

---

### Pitfall 7: Fixed SVG viewBox Clips Large Schemas

**What goes wrong:** The current SVG element has a hardcoded `viewBox "0 0 520 520"`. Real-world schemas (OpenAPI Petstore already in `Main.elm`) will produce diagrams far larger than 520x520. The SVG will silently clip content outside the viewBox.

**Why it happens:** The renderer threads coordinates starting at `(0, 0)` and accumulates dimensions, but the outer `Svg.svg` element has no awareness of the final computed dimensions. There is no mechanism to feed the computed `Dimensions` back into the SVG container attributes.

**Consequences:** Large schemas appear partially rendered with no error or indication that content is clipped.

**Prevention:** One of two approaches: (a) compute total dimensions in a first pass before rendering, then set `viewBox` dynamically; or (b) use a fixed large viewBox with `overflow: auto` on the containing `<div>` and let the SVG scroll. Approach (b) is simpler and sufficient for v1. Set `viewBox "0 0 4000 4000"` initially and make the containing `<div>` scrollable via CSS. The dynamic approach requires running the layout algorithm twice (once to compute bounds, once to render), which can be unified by having the render pass also return overall bounds.

**Detection:** Load the Petstore Swagger schema in `Main.elm` and verify all Pet/Category/Tag/Order definitions are visible, not clipped.

**Affects phases:** Phase handling real-world schemas; should be addressed before or during Phase 1.

---

### Pitfall 8: Elm's Recursive Type Restriction Requires Wrapping for Mutual Recursion

**What goes wrong:** Elm 0.19.1 does not allow directly recursive type aliases. `type alias Schema = { ... properties : List Schema }` will not compile. This is already handled in the codebase via a `type Schema = Object ObjectSchema | ...` union type. However, when adding new data structures for expand/collapse state trees (e.g. a tree mirroring the schema tree), the same restriction applies. A naive `type alias NodeState = { expanded : Bool, children : List NodeState }` is a recursive type alias and will fail to compile.

**Why it happens:** Elm prohibits recursive type aliases (infinite expansion at compile time) but allows recursive `type` union types. The distinction is: type aliases must be structurally finite, while union types can be recursive via lazy evaluation.

**Consequences:** Compiler error: "This type alias is recursive, causing an infinite type." The fix requires converting to a `type` union.

**Prevention:** Any tree-shaped data structure for UI state must use `type` not `type alias`. The correct form:

```elm
type NodeState
    = NodeState { expanded : Bool, children : List NodeState }
```

Use this pattern from the start for any expand/collapse tree.

**Detection:** Attempt to compile after adding a recursive type alias. The error message is clear and points to the offending type.

**Affects phases:** Phase designing expand/collapse state tree.

---

### Pitfall 9: `Dict String expandState` with Path Keys Has Performance Cliff on Large Schemas

**What goes wrong:** Storing expand/collapse state as `Dict String Bool` keyed by path string is simple and correct for small schemas. For large OpenAPI specs with hundreds of definitions, each user interaction requires traversing the full model and re-rendering the full SVG tree. Elm's virtual DOM diffing helps for HTML but SVG re-rendering of hundreds of nodes is noticeably slow.

**Why it happens:** Elm re-runs the entire `view` function on every model change. The SVG renderer walks the full schema tree recursively. With 200+ nodes, each render takes longer. Elm's `Svg.Lazy.lazy` (already imported in `Render.Svg`) can short-circuit subtrees that have not changed, but only if the arguments to `lazy` are reference-equal (not structurally equal).

**Consequences:** Noticeable lag (>100ms) on click for large schemas. Feels unresponsive.

**Prevention:** Use `Svg.Lazy.lazy` (already imported) at object and array node boundaries, passing the expand state for that subtree as an argument. Only the path to the toggled node needs to re-render. Ensure the expand state passed to each `lazy`-wrapped subtree is the minimal slice relevant to that subtree, not the entire `Dict`. The `Dict String Bool` keyed by full path naturally enables this: pass `Dict.filter (\k _ -> String.startsWith path k) expandState` to each node's `lazy` call.

**Detection:** Load a schema with 50+ properties across multiple levels. Measure frame time on click using browser DevTools Performance panel. Greater than 16ms per frame is the threshold.

**Affects phases:** Phase handling large schemas (likely later phase); flag for performance testing.

---

### Pitfall 10: File Input for Schema Upload Requires a Port or Flags (Cannot Be Done in Pure Elm)

**What goes wrong:** `Browser.element` supports `flags` for initial data, but reading a file selected by `<input type="file">` requires a `FileReader` API call. In Elm 0.19.1, this can be accomplished via the `elm/file` package (`File.toBytes`, `File.toString`) without ports — but this is often missed, and developers either try to use ports (adding JS complexity) or give up on file upload entirely.

**Why it happens:** The `elm/file` package was added in 0.19.1 and is not widely known. `Browser.sandbox` cannot use `Cmd`, so file reading is impossible in sandbox mode. The feature is only available after migrating to `Browser.element`.

**Consequences:** Over-engineering with ports where `elm/file` would suffice, or under-delivering (paste-only, no file upload).

**Prevention:** Use `elm/file` for file upload after migrating to `Browser.element`. The pattern is: `Html.Events.on "change" (Decode.map GotFile File.decoder)` on the file input element, then `Task.perform GotFileContent (File.toString file)` in update. No ports required.

**Detection:** Check whether `elm/file` is in `elm.json` dependencies. It is not currently listed, so it needs to be added (`elm install elm/file`).

**Affects phases:** Phase adding user input (paste/upload).

---

## Minor Pitfalls

---

### Pitfall 11: computeTextWidth Uses a Fixed Character Width That Breaks for Non-ASCII

**What goes wrong:** `computeTextWidth` in `Render/Svg.elm` multiplies character count by `7.2`. This is an approximation for ASCII monospace. Unicode characters (property names in non-English schemas), emoji in descriptions, or variable-width glyphs will cause text to overflow or under-fill its pill container.

**Prevention:** Accept the approximation for v1 but add a minimum padding constant. For v2, consider using SVG `getComputedTextLength()` via a port if precision is required. For now, document the limitation.

**Affects phases:** Phase rendering real-world schemas; low priority for v1.

---

### Pitfall 12: Decoder Does Not Handle `$ref` as the Sole Schema (Non-Object Context)

**What goes wrong:** JSON Schema allows `$ref` to appear as the top-level schema (not wrapped in an object). The current decoder likely handles `$ref` only as a property value. A schema file that starts with `{ "$ref": "#/definitions/Foo" }` at the root may decode as `Fallback` rather than `Ref`.

**Prevention:** Test the decoder with a root-level `$ref` schema before implementing inline `$ref` expansion. If it decodes to `Fallback`, the render pipeline silently produces an empty diagram with no error visible to the user.

**Affects phases:** Phase implementing $ref resolution.

---

### Pitfall 13: `Svg.Lazy.lazy` Arguments Must Be Reference-Equal, Not Structurally Equal

**What goes wrong:** `Svg.Lazy.lazy f arg` skips re-rendering only if `arg` is reference-equal (same pointer) to the previous call's arg, not structurally equal. Creating a new `Dict` or `List` from scratch on each `view` call means `lazy` never skips anything, providing no benefit.

**Prevention:** Ensure that unchanged subtrees receive the exact same data structure reference. For `Dict` values passed to `lazy`, use `Dict.get` to pass a `Maybe Bool` (which is a scalar) rather than a sub-dict constructed on each render.

**Affects phases:** Performance optimization phase; low priority initially.

---

### Pitfall 14: oneOf/anyOf/allOf Sub-Schemas Have No Stable Identity

**What goes wrong:** `BaseCombinatorSchema` stores `subSchemas : List Schema`. List elements have positional identity only. If a sub-schema is itself a `Ref`, its position in the list could change if the decoder's ordering changes. Expand/collapse state keyed by list index is fragile.

**Prevention:** Key combinator sub-schemas by their index within the parent combinator node's path: `["oneOf", "0"]`, `["oneOf", "1"]`, etc. This is stable as long as the decoder output order is stable (which it is, since it follows the JSON array order).

**Affects phases:** Phase implementing expand/collapse for combinator schemas.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Cleanup / Production Build | Debug.log calls block `--optimize` builds | Remove all three existing `Debug.log` calls before any other work |
| Browser.sandbox migration | Type errors cascade if done mid-feature | Migrate as isolated commit, compile-check before proceeding |
| User input (paste/upload) | File reading needs `elm/file`, not ports | Add `elm/file` dependency; use `File.toString` task |
| SVG click handlers | Event bubbling triggers parent and child handlers | Use `stopPropagationOn "click"` on every interactive node |
| Expand/collapse state design | Non-unique property names cause wrong node toggled | Design path-based keys `List String` before wiring any state |
| Expand/collapse layout | Collapsed nodes return wrong dimensions, causing overlap | Update both render path and dimension return simultaneously |
| Recursive UI state tree | Recursive type alias won't compile | Use `type NodeState = NodeState { ... }` not `type alias` |
| $ref inline expansion | Circular references cause infinite recursion | Thread `Set String` of visited refs through render calls |
| Real-world schemas | Fixed 520x520 viewBox clips content | Use large viewBox + CSS overflow scroll on container |
| Large schema performance | Full re-render on every click | Use `Svg.Lazy.lazy` at node boundaries; pass minimal state slices |

---

## Sources

- Direct analysis of `/home/eelco/Source/elm/jsonschema-viewer/src/Render/Svg.elm` — HIGH confidence
- Direct analysis of `/home/eelco/Source/elm/jsonschema-viewer/src/Json/Schema.elm` — HIGH confidence
- Direct analysis of `/home/eelco/Source/elm/jsonschema-viewer/src/Main.elm` — HIGH confidence
- Elm 0.19.1 language specification (recursive type aliases, `--optimize` flag behavior) — HIGH confidence
- Elm `Browser.sandbox` vs `Browser.element` API contracts — HIGH confidence
- Elm `Svg.Lazy` reference equality semantics — HIGH confidence
- JSON Schema draft-07 circular reference specification — HIGH confidence
- SVG DOM event bubbling specification (W3C) — HIGH confidence
