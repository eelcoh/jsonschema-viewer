# Technology Stack

**Project:** JSON Schema Viewer — Interactive SVG Diagram
**Researched:** 2026-04-03
**Confidence:** HIGH (Elm 0.19.1 ecosystem is stable and frozen since 2019; core packages do not change)

---

## Current Stack (Already in Place — Do Not Re-research)

| Technology | Version | Purpose |
|------------|---------|---------|
| elm/core | 1.0.4 | Core language |
| elm/browser | 1.0.2 | Application entry point |
| elm/html | 1.0.0 | HTML rendering |
| elm/svg | 1.0.1 | SVG rendering |
| elm/json | 1.1.2 | JSON decoding |
| NoRedInk/elm-json-decode-pipeline | 1.0.0 | Decoder ergonomics |
| avh4/elm-color | 1.0.0 | Color utilities |
| noahzgordon/elm-color-extra | 1.0.2 | Color conversion (hex) |
| elm-community/list-extra | 8.2.4 | List utilities |

---

## Required Stack Additions

### 1. Browser Entry Point: Upgrade from `Browser.sandbox` to `Browser.element`

**What to change:** `Main.elm` currently uses `Browser.sandbox`. Replace with `Browser.element`.

**Why `Browser.element` and not `Browser.document`:**
- `Browser.element` embeds the Elm app inside a specific DOM node — exactly what Create Elm App scaffolds (it mounts into `<div id="root">`). This is the right choice for the current setup.
- `Browser.document` takes over the entire `<body>` and controls `<title>`. Unnecessary here — we have no need to manage the page title dynamically or restructure the HTML shell.
- `Browser.sandbox` has no `Cmd`, no `Sub`, and no flags — it cannot receive user input events from outside Elm (file reads require `Task`/`Cmd`), cannot use `Html.Events.on` for file input change events that produce `Cmd`, and cannot manage the expand/collapse state update cycle that may eventually need subscriptions.

**What `Browser.element` adds over `Browser.sandbox`:**
- `init` receives `flags` from JavaScript (not needed now but available)
- `update` returns `( Model, Cmd Msg )` — needed for `File.toString` task
- `subscriptions` field — available for future keyboard shortcuts or window resize
- No other structural changes to the architecture are needed

**Migration cost:** LOW. Change `Browser.sandbox` to `Browser.element`, add `Cmd.none` to `update`, add empty `subscriptions`, change `init` signature. No new package required — `elm/browser` is already a dependency at 1.0.2.

**Confidence:** HIGH — `Browser` module is part of elm/browser 1.0.2, already in elm.json.

---

### 2. File Upload: `elm/file` Package

**Add:** `elm/file` at version `1.0.5`

**Why:** File upload (reading a `.json` file the user selects) requires:
- `File.Select.file` — opens the OS file picker, returns a `Cmd Msg` with a `File` value
- `File.toString` — reads the file contents as a `String`, returns a `Task Never String`
- `Task.perform` — converts the Task to a `Cmd Msg` so the result arrives as a `Msg`

This is the idiomatic Elm approach. No JavaScript ports required.

**Why not ports for file reading:** The constraint is "no JS interop for core features." `elm/file` is pure Elm API over the browser File API — no custom ports needed.

**Installation:**
```bash
elm install elm/file
```

This adds `elm/file` to `elm.json` direct dependencies. It transitively requires `elm/bytes` (already available as an indirect dep via the Elm package ecosystem).

**Usage pattern:**
```elm
-- In your Msg type:
type Msg
    = SchemaTextChanged String
    | FileRequested
    | FileSelected File
    | FileLoaded String

-- In update:
FileRequested ->
    ( model, File.Select.file [ "application/json", ".json" ] FileSelected )

FileSelected file ->
    ( model, Task.perform FileLoaded (File.toString file) )

FileLoaded contents ->
    ( { model | schemaInput = contents, parsedSchema = Json.Decode.decodeString decoder contents }
    , Cmd.none
    )
```

**Confidence:** HIGH — `elm/file` is an official Elm package, stable since Elm 0.19.

---

### 3. Text Area Input: No New Package Required

**What to use:** `Html.textarea` from `elm/html` (already a dependency).

**Why no new package:** A `<textarea>` for pasting JSON Schema text is a standard HTML element fully covered by `elm/html`. The `Html.Events.onInput` event gives you `String -> msg` on every keystroke. No additional package needed.

**Pattern:**
```elm
Html.textarea
    [ Html.Attributes.value model.schemaInput
    , Html.Events.onInput SchemaTextChanged
    , Html.Attributes.placeholder "Paste JSON Schema here..."
    , Html.Attributes.rows 20
    , Html.Attributes.cols 80
    ]
    []
```

Parsing should be debounced or triggered on a "Parse" button click rather than on every keystroke — large schemas will cause lag if decoded on every character. Use a `ParseSchema` message triggered by a button.

**Confidence:** HIGH — core elm/html, no new dependency.

---

### 4. Interactive SVG (Expand/Collapse): No New Package Required

**What to use:** `Svg.Events.onClick` from `elm/svg` (already a dependency at 1.0.1).

**Why no new package:** SVG click events in Elm are handled via `Svg.Events`, which is part of `elm/svg`. The expand/collapse state lives in the `Model` as a `Set String` (collapsed node IDs) using `elm/core`'s `Set` module.

**Pattern:**
```elm
-- Track collapsed nodes by a stable path key
type alias Model =
    { ...
    , collapsedNodes : Set String
    }

-- Msg
type Msg
    = ToggleNode String  -- node path key

-- In update
ToggleNode key ->
    let
        newCollapsed =
            if Set.member key model.collapsedNodes then
                Set.remove key model.collapsedNodes
            else
                Set.insert key model.collapsedNodes
    in
    ( { model | collapsedNodes = newCollapsed }, Cmd.none )

-- In Render.Svg, attach click handler to node group:
Svg.g
    [ Svg.Events.onClick (ToggleNode nodeKey) ]
    [ ... ]
```

**Node key strategy:** Use a path string like `"root.properties.fruits"` or `"definitions.veggie"`. This is deterministic from the traversal and requires no extra ID tracking in the schema model.

**Why `Set String` over `Dict String Bool`:** A `Set` of collapsed IDs is simpler — membership means collapsed, absence means expanded. The default state (everything expanded) requires no initialization beyond `Set.empty`.

**Important:** `Svg.Events` is a sub-module of `elm/svg`. It is NOT separately installed — it comes with `elm/svg 1.0.1`. Just import it:
```elm
import Svg.Events
```

**Confidence:** HIGH — `Svg.Events.onClick` is part of the official `elm/svg` package.

---

### 5. Layout Algorithm: No New Package — Pure Elm Implementation

**What to use:** Extend the existing coordinate-threading pattern in `Render.Svg`.

**Why no layout library:** There are no widely-adopted Elm layout graph libraries for SVG tree diagrams (the ecosystem is small). The existing coordinate-threading approach `(Svg msg, Dimensions)` is the correct foundation. It needs extensions, not replacement.

**What needs to change in the layout:**
- The current layout threads coordinates left-to-right, placing children to the right of parents. This works for shallow schemas.
- For deep schemas (real-world OpenAPI component schemas with `$ref` chains), the SVG viewport needs to be dynamic — the `width` and `height` attributes on `<svg>` must be computed from the returned `Dimensions` rather than hardcoded at `"520"`.
- The `viewBox` should be computed: `"0 0 {totalWidth} {totalHeight}"`.
- Connector lines between parent nodes and children need to be drawn as `<line>` or `<path>` elements — currently missing.

**Scrollable viewport:** Rather than making the SVG itself scroll, wrap it in a `<div>` with `overflow: auto` and let the SVG grow to its natural size. This is trivial in HTML/CSS and requires no Elm package.

**Confidence:** HIGH — based on direct analysis of existing code and Elm SVG capabilities.

---

### 6. `$ref` Resolution Rendering: No New Package — Model Change

**Current state:** `Render.Svg` looks up `$ref` in `Definitions` but renders only a stub label (`roundRect ref (w + 10, y)`) rather than expanding the referenced schema inline.

**Fix approach:** Pass the full `Definitions` dict (already threaded through as the `defs` argument) and render the referenced schema inline by recursing with `viewSchema`. Guard against circular `$ref` cycles using a `Set String` of currently-being-rendered refs:

```elm
viewSchema : Definitions -> Set String -> Coordinates -> Maybe Name -> Schema -> ( Svg msg, Dimensions )
```

The extra `Set String` argument is a visited-refs guard. If the ref key is already in the set, render a stub instead of recursing. This prevents infinite loops on circular schemas.

**No new package needed** — `elm/core` `Set` is sufficient.

**Confidence:** HIGH — this is a pure algorithmic change within existing code.

---

## Packages to NOT Add

| Package | Why Not |
|---------|---------|
| Any graph layout library (e.g., hypothetical `elm-dagre`) | None exists in Elm 0.19 ecosystem with sufficient maturity; the coordinate-threading pattern already in place is adequate for tree layouts |
| `elm/http` | All processing is client-side; no server calls needed |
| Any port-based JS interop for file handling | `elm/file` covers this natively |
| `mdgriffith/elm-ui` | The app renders SVG, not HTML layout; elm-ui is for HTML-first UIs and adds significant learning overhead for no gain here |
| `elm/animation` or any animation library | Not in scope for v1; expand/collapse is instant state toggle |
| Any virtual DOM diffing optimizer | Elm's virtual DOM is sufficient; only optimize if profiling shows a problem |
| `elm-explorations/browser` (test helper) | Not needed for production code |

---

## Summary: What Actually Needs to Be Added

Only **one new package** is required:

```bash
elm install elm/file
```

Everything else — SVG click events, textarea input, expand/collapse state, layout — is achievable with packages already present in `elm.json`.

The architectural change is `Browser.sandbox` → `Browser.element` in `Main.elm`, which requires no new package.

---

## Recommended Stack (Complete)

### Core Application

| Technology | Version | Purpose | Status |
|------------|---------|---------|--------|
| elm/core | 1.0.4 | Language core, Dict, Set, Task | Already present |
| elm/browser | 1.0.2 | `Browser.element` entry point | Already present; upgrade sandbox → element |
| elm/html | 1.0.0 | Textarea, buttons, layout wrapper | Already present |
| elm/svg | 1.0.1 | SVG rendering + `Svg.Events.onClick` | Already present |
| elm/json | 1.1.2 | JSON decoding of pasted schema | Already present |
| elm/file | 1.0.5 | File picker + read file as string | **ADD THIS** |

### Schema Modeling

| Technology | Version | Purpose | Status |
|------------|---------|---------|--------|
| NoRedInk/elm-json-decode-pipeline | 1.0.0 | Decoder ergonomics | Already present |
| elm-community/list-extra | 8.2.4 | List manipulation for properties | Already present |

### Visual Utilities

| Technology | Version | Purpose | Status |
|------------|---------|---------|--------|
| avh4/elm-color | 1.0.0 | Color values | Already present |
| noahzgordon/elm-color-extra | 1.0.2 | Color-to-hex for SVG fill/stroke | Already present |

---

## Pre-Production Cleanup Required

Before any production build (`elm make --optimize`):

- Remove all `Debug.log` calls in `Render/Svg.elm`:
  - Line 37: `Debug.log "schema "` in `view`
  - Line 668: `Debug.log "text color"` in `iconGeneric`
  - Line 708: `Debug.log "red"` and `Debug.log "color"` in `color`

`elm make --optimize` will refuse to compile with `Debug` calls present. This is a hard blocker for production builds, not a warning.

---

## Sources

- Elm 0.19.1 documentation is stable and frozen — changes to core packages do not occur after a major release
- `elm/browser` Browser module API: https://package.elm-lang.org/packages/elm/browser/latest/Browser
- `elm/file` package: https://package.elm-lang.org/packages/elm/file/latest/
- `elm/svg` Svg.Events module: https://package.elm-lang.org/packages/elm/svg/latest/Svg-Events
- Direct codebase analysis: `/home/eelco/Source/elm/jsonschema-viewer/elm.json`, `src/Main.elm`, `src/Render/Svg.elm`
- Confidence: HIGH — Elm 0.19.1 package ecosystem is stable; core APIs have not changed since release
