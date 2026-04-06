# Architecture Patterns

**Domain:** Interactive SVG diagram viewer (JSON Schema)
**Researched:** 2026-04-03

---

## Existing Architecture (What We Have)

The proof-of-concept is a `Browser.sandbox` with a pure rendering pipeline:

```
JSON string (hardcoded)
  → Json.Decode.decodeString decoder
  → Result Json.Decode.Error Json.Schema.Model
  → Render.Svg.view defs schema
  → Html.Html msg (SVG wrapped in Html)
```

Three modules:
- `Json.Schema` — type definitions (Schema union, Definitions dict, ObjectProperty)
- `Json.Schema.Decode` — draft-07 decoder, recursive via `lazy`
- `Render.Svg` — coordinate-threading renderer: each fn returns `(Svg msg, Dimensions)`

Key characteristics of the renderer:
- `viewSchema` dispatches on `Schema` variant
- Layout is computed bottom-up: callee returns its own bounding box `(width, height)`
- No state, no messages, no interaction — pure `msg` parameter never used
- `Debug.log` calls are embedded and must be removed

---

## Target Architecture: What Needs to Change

### 1. Browser.sandbox → Browser.element

`Browser.sandbox` has no `Cmd`, no subscriptions, and no `Flags`. Adding user input (paste/file upload) requires `Browser.element` for:
- `Html.Events.on "change"` for file input (needs `File` API via ports or `elm/file`)
- No `Cmd` is required if using only textarea input, but `Browser.element` is the right upgrade path regardless

The `Model` type in `Main.elm` changes from `Result Json.Decode.Error Json.Schema.Model` to a record that also holds UI state.

### 2. New Model Shape

```elm
type alias Model =
    { schemaInput : String
    , parseResult : Result String Json.Schema.Model
    , expandState : ExpandState
    }

type alias ExpandState =
    Set NodePath

type alias NodePath =
    List String
```

`NodePath` uniquely identifies a node in the schema tree by the sequence of property names (and special segments like `"items"`, `"oneOf[0]"`, `"$ref"`) traversed to reach it. Example: `["vegetables", "items"]` identifies the items schema of the `vegetables` property.

### 3. Msg Additions

```elm
type Msg
    = SchemaInputChanged String
    | ToggleNode NodePath
    | NoOp
```

`SchemaInputChanged` triggers re-parse. `ToggleNode` flips membership of a path in `ExpandState`.

### 4. ExpandState Data Structure

Use `Set (List String)` (which requires `Set` from `elm/core` with `comparable` — `List String` is comparable). A path is "expanded" if it is a member of the set.

Default state: all container nodes collapsed (empty set), or optionally root expanded. The first render should show root expanded and all children collapsed so the diagram is immediately useful.

---

## Recommended Architecture

```
Browser.element
│
├── Model
│   ├── schemaInput : String          -- raw textarea content
│   ├── parseResult : Result String Json.Schema.Model
│   └── expandState : Set NodePath    -- which nodes are open
│
├── Update
│   ├── SchemaInputChanged s  →  re-parse, reset expandState
│   └── ToggleNode path       →  Set.toggle path expandState
│
└── View
    ├── Html textarea / file input
    └── Render.Svg.view defs schema expandState
        └── viewSchema defs expandState path schema
            ├── if path ∈ expandState → render children
            └── else → render collapsed node with click handler
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `Main.elm` | App shell, Model, Msg, update, input UI | `Json.Schema.Decode`, `Render.Svg` |
| `Json.Schema` | Schema type definitions — NO changes needed | Referenced by all modules |
| `Json.Schema.Decode` | Decoder — NO changes needed | Used by `Main.elm` |
| `Render.Svg` | SVG layout and rendering — SIGNIFICANT changes | Receives `expandState`, emits `Msg` |

### New Module: `Diagram.NodePath` (recommended)

Extract path logic into its own module to keep `Render.Svg` clean:

```elm
module Diagram.NodePath exposing (NodePath, child, items, ref, combinator, toString)

type alias NodePath = List String

child : String -> NodePath -> NodePath
items : NodePath -> NodePath
ref : String -> NodePath -> NodePath
combinator : Int -> NodePath -> NodePath
```

This isolates path construction rules and makes them testable.

---

## Data Flow Changes for Interactivity

### Current flow (pure rendering)

```
viewSchema defs coords name schema
  → (Svg msg, Dimensions)
```

### New flow (interactive rendering)

```
viewSchema defs expandState path coords name schema
  → (Svg Msg, Dimensions)
```

Two new parameters thread through all view functions:
- `expandState : Set NodePath` — read-only, checked at each expandable node
- `path : NodePath` — the address of the current node, built up as recursion descends

Every call to `viewSchema` appends to `path` before the recursive call. When the renderer reaches an expandable node (`Object`, `Array`, `OneOf`, `AnyOf`, `AllOf`, `Ref`):

1. Render the node header pill with an `onClick (ToggleNode path)` attribute on the rect or a collapse/expand indicator
2. Check `Set.member path expandState`
3. If expanded: render children as before, passing `child propName path` as the path for each child
4. If collapsed: render only the header, children omitted from SVG output

### Connector Lines

Currently absent from the renderer. They are needed to show tree structure. A connector line runs from the right edge of the parent pill to the left edge of each child pill. Since each `view*` function already returns its bounding `Dimensions`, connector coordinates can be computed during layout — no structural change needed, just additional `Svg.line` elements emitted alongside child groups.

### SVG Viewport

The current hardcoded `520x520` viewport is inadequate for real schemas. Change to:
- Compute total diagram dimensions from the root node's returned `Dimensions`
- Emit `viewBox "0 0 {w} {h}"` dynamically
- Wrap in a scrollable `Html.div` with overflow scroll, or use SVG `viewBox` with a fixed viewport and pan

For v1, a simple approach is to compute dimensions from the rendered schema and use that as the SVG size. Pan/zoom can come later.

---

## Patterns to Follow

### Pattern 1: Thread State Through View Functions, Don't Use Global Refs

Pass `expandState` and `path` as explicit parameters down the call tree. Do not use module-level state or global configuration.

```elm
viewSchema :
    Definitions
    -> Set NodePath
    -> NodePath
    -> Coordinates
    -> Maybe Name
    -> Schema
    -> ( Svg Msg, Dimensions )
```

All callers (`viewProperties`, `viewItems`, `viewMulti`, etc.) need matching signature updates.

### Pattern 2: Collapse Toggle as onClick on the Pill Rect

```elm
Svg.rect
    [ ...existing attrs...
    , Svg.Events.onClick (ToggleNode currentPath)
    ]
    []
```

No JS interop needed. `Svg.Events` is in `elm/svg`.

### Pattern 3: Ref Expansion as Toggle (NOT Auto-Inline)

When a `Ref` node is collapsed, show the reference label. When expanded, look up the definition in `Definitions` and render the resolved schema inline, using the ref path as the parent path prefix. This prevents infinite loops from circular refs by using `NodePath` depth as a natural limit — if the path already contains the same ref segment, stop rendering.

```elm
-- In viewSchema, Schema.Ref branch:
if Set.member path expandState then
    case Dict.get ref defs of
        Nothing -> renderRefLabel name ref coords
        Just resolvedSchema ->
            let refPath = Diagram.NodePath.ref refName path
            in  renderRefLabel name ref coords
                    |> withExpanded (viewSchema defs expandState refPath ...)
else
    renderRefLabel name ref coords |> withCollapseIndicator
```

### Pattern 4: Input Area as Plain HTML Textarea

Keep schema input as a `Html.textarea` with `onInput SchemaInputChanged`. Parse on every change with `Json.Decode.decodeString decoder`. Show error text when parse fails. No debouncing needed for v1 — Elm's virtual DOM is fast enough for schema-size inputs.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Global Mutable Expand State Outside Elm Model

Storing expand state in JS (localStorage, window vars) via ports for v1 is unnecessary complexity. Keep it in Elm Model.

### Anti-Pattern 2: Pre-Expanding All Nodes

Rendering the entire schema expanded on first load defeats the purpose of expand/collapse and causes layout explosions on large schemas. Default to root-expanded, rest collapsed.

### Anti-Pattern 3: Recomputing Layout on Every Render Unnecessarily

The coordinate-threading pattern is already efficient — layout is computed once per render pass as part of the SVG generation. Do not add a separate "compute layout" phase or cache layout separately. Let `Render.Svg.view` remain a pure function of `(Definitions, Schema, ExpandState)`.

### Anti-Pattern 4: Using Elm's `Svg.Lazy` for Individual Nodes

`Svg.Lazy` caches based on reference equality of arguments. Since `expandState` changes on every toggle, any node that receives it as an argument will not benefit from lazy. Reserve `Svg.Lazy` for the top-level view call only, and only after profiling confirms it is needed.

### Anti-Pattern 5: Keeping Debug.log in Render.Svg

`Debug.log` is already present in `iconGeneric` (text color) and `color` function. These must be removed before any interactivity work — they cause `elm make --optimize` to fail and they fire on every render, which will be very noisy once interactions trigger re-renders.

---

## Build Order (Phase Dependencies)

### Step 1: Remove Debug.log and fix production build

**Why first:** `Debug.log` in `Render.Svg` fires on every render. With interactions triggering frequent re-renders it becomes unusable noise, and blocks optimized builds. Also validates the existing code compiles cleanly.

Files changed: `Render.Svg`

### Step 2: Upgrade to Browser.element, add textarea input

**Why second:** Unblocks user input. The Model becomes a record. `SchemaInputChanged` msg and basic parse error display. No expand state yet — renderer stays unchanged, just wired to user input.

Files changed: `Main.elm`

### Step 3: Add NodePath module and ExpandState to Model

**Why third:** Defines the data structures before the renderer needs them. `Diagram.NodePath` module created. `ExpandState` (Set NodePath) added to Model. `ToggleNode` msg added. No visual change yet.

Files new/changed: `Diagram/NodePath.elm` (new), `Main.elm`

### Step 4: Thread expandState and path through Render.Svg

**Why fourth:** This is the large refactor — all view function signatures change. Compile-driven: start from `view`, work down. Nodes that are expandable get `onClick (ToggleNode path)`. Non-container nodes (String, Integer, etc.) just receive path but don't use it.

Files changed: `Render.Svg`

### Step 5: Implement expand/collapse visibility (hide children when collapsed)

**Why fifth:** Now that paths are threaded, actually suppress child rendering when `Set.notMember path expandState`. Add expand/collapse indicator (a small +/- or triangle) to container nodes.

Files changed: `Render.Svg`

### Step 6: Implement $ref inline expansion

**Why sixth:** Depends on expand/collapse working. When a Ref node is expanded, look up the definition and render it inline. Add circular-ref guard via path inspection.

Files changed: `Render.Svg`, possibly `Diagram.NodePath`

### Step 7: Add connector lines between parent and child nodes

**Why seventh:** Connector lines require knowing the bounding boxes of parent and children — this is already available from the coordinate-threading pattern, so no structural change, just additional SVG elements. Best added after expand/collapse is stable so lines appear/disappear correctly.

Files changed: `Render.Svg`

### Step 8: Dynamic SVG viewport

**Why last:** Depends on all layout work being stable. Compute diagram dimensions from root node's returned Dimensions, emit correct viewBox. Wrap in scrollable container.

Files changed: `Main.elm`, `Render.Svg`

---

## Scalability Considerations

| Concern | At small schemas | At medium schemas (50+ nodes) | At large schemas (200+ nodes) |
|---------|-----------------|-------------------------------|-------------------------------|
| Render performance | No issue | No issue — Elm VDOM is fast | Consider collapsing subtrees by default |
| Layout computation | Instant | Instant | Still instant — O(n) coordinate threading |
| Circular $ref | Not a problem if no $refs | Medium risk | High risk — path-based guard required |
| SVG viewport | Fixed 520x520 works | Needs dynamic sizing | Needs dynamic sizing + scroll |

---

## Integration Points Summary

| Feature | Touches Existing Code | New Code |
|---------|----------------------|----------|
| Browser.element upgrade | `Main.elm` — minimal changes | New Model record fields |
| Textarea input | `Main.elm` — add view, msg | `SchemaInputChanged` handler |
| ExpandState | `Main.elm` — Model field | `Diagram.NodePath` module |
| onClick on pills | `Render.Svg` — add `Svg.Events.onClick` | None |
| Thread path/expandState | `Render.Svg` — all view fn signatures | None |
| Expand/collapse visibility | `Render.Svg` — conditional child rendering | Collapse indicator SVG |
| $ref inline expansion | `Render.Svg` — Ref branch | Circular-ref guard |
| Connector lines | `Render.Svg` — new SVG lines in layout fns | None |
| Dynamic viewport | `Main.elm` + `Render.Svg` — return total dims | None |

---

## Sources

- Elm 0.19.1 Browser module documentation (Browser.element vs Browser.sandbox): https://package.elm-lang.org/packages/elm/browser/latest/Browser
- Elm SVG events: https://package.elm-lang.org/packages/elm/svg/latest/Svg-Events
- Elm Set (comparable keys including List String): https://package.elm-lang.org/packages/elm/core/latest/Set
- Source analysis of existing `Render.Svg`, `Json.Schema`, `Json.Schema.Decode`, `Main.elm` (HIGH confidence — direct code read)
- Pattern derivation from Altova XMLSpy / Liquid XML Studio interaction model (MEDIUM confidence — behavioral observation of reference products)
