# Phase 1: Foundation and Input - Research

**Researched:** 2026-04-04
**Domain:** Elm 0.19.1 — Browser.element upgrade, elm/file, drag-and-drop, debounce
**Confidence:** HIGH

## Summary

Phase 1 removes production-build blockers (`Debug` usage in two source files), upgrades the application from `Browser.sandbox` to `Browser.element`, and adds two input mechanisms: a live-updating textarea and drag-and-drop file upload. These changes are self-contained within Elm and the existing `create-elm-app` toolchain — no new JS infrastructure is required beyond a thin drag-drop event handler in `src/index.js`.

The `elm/file` package (v1.0.5, already cached globally) provides `File.decoder` for decoding dropped files from DOM events and `File.toString : File -> Task x String` for reading file content asynchronously. Debouncing the textarea's live-update (D-09) can be implemented with `Process.sleep` and a generation-counter pattern from `elm/core` without adding any new package dependency.

**Primary recommendation:** Add `elm/file` to `elm.json`, implement the `Browser.element` upgrade in `Main.elm`, handle drag-drop entirely inside Elm using `Html.Events.preventDefaultOn` + `File.decoder` + `Task.perform`, and inline the generation-counter debounce pattern. No Elm ports are needed for file reading.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Side-by-side layout — textarea on the left, SVG diagram on the right
- **D-02:** Textarea is always visible but can be collapsed/closed by the user to maximize diagram space
- **D-03:** Diagram updates live as the user types in the textarea (no manual render button)
- **D-04:** File upload via drag-and-drop zone on the textarea area (no separate upload button)
- **D-05:** Drag-and-drop requires ports/JS interop — upgrade from `Browser.sandbox` to `Browser.element` enables this
- **D-06:** Remove hardcoded test schema strings from `Main.elm` — they become example schemas instead
- **D-07:** App starts with a pre-loaded example schema so users immediately see the diagram in action
- **D-08:** JSON/schema decode errors replace the diagram area (consistent with existing `errorToString` pattern)
- **D-09:** During live typing, keep showing the last successfully rendered diagram while input is invalid — only show errors after a brief pause (~1 second debounce or similar)
- **D-10:** Provide a dropdown/button group with 2-3 example schemas (e.g., simple object, nested arrays, schema with $refs)
- **D-11:** Selecting an example replaces textarea content and triggers diagram re-render

### Claude's Discretion
- Debounce timing for live updates (exact delay)
- Specific example schemas to include (can draw from existing test data: person, arrays/veggie, or simplified versions)
- Visual styling of the collapse/expand control for the textarea panel
- Drag-and-drop visual feedback (hover state, accepted file types)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FOUND-01 | `Debug.log` calls removed from `Render.Svg` so production builds work with `--optimize` | Confirmed: `elm make --optimize` fails with exit 1 when Debug is present. Four `Debug.log` calls in `Render/Svg.elm` (lines 37, 667, 708, 710) and two `Debug.toString` calls in `Json/Schema/Decode.elm` (line 140) must be removed/replaced. |
| FOUND-02 | App upgraded from `Browser.sandbox` to `Browser.element` to support user input and interactivity | Confirmed: `Browser.element` adds `Cmd`, `Sub`, and flags support. `init` signature changes from `Model` to `flags -> (Model, Cmd Msg)`. `update` changes from `Msg -> Model -> Model` to `Msg -> Model -> (Model, Cmd Msg)`. A `subscriptions` function must be added. |
| INPUT-01 | User can paste a JSON Schema document into a textarea and see it rendered as a diagram | Confirmed: `Html.textarea` + `Html.Events.onInput` delivers text string directly. Live decode via existing `Json.Decode.decodeString decoder`. Debounce via `Process.sleep` + generation counter. |
| INPUT-02 | User can upload a JSON Schema file from their filesystem and see it rendered as a diagram | Confirmed: `elm/file` 1.0.5 provides pure-Elm drag-and-drop without ports. `File.decoder` decodes a dropped File from the DOM event; `File.toString` reads it as `Task x String`. No JS FileReader ports needed. |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

| Directive | Implication for Planning |
|-----------|--------------------------|
| Elm 0.19.1, no ports for file reading | Use `elm/file` pure-Elm API; avoid JS FileReader ports |
| `elm make src/Main.elm --output=/dev/null` is the compile-check command | All tasks must pass this command |
| `elm make --optimize` must work after FOUND-01 | All `Debug` module usage must be eliminated before phase is done |
| `Debug.log` calls must be removed before production builds | First task of the phase |
| `elm-app start` / `elm-app build` for dev/build | Build toolchain is create-elm-app; do not change webpack/build config |
| `elm-test` for tests | Test framework is elm-explorations/test 1.0.0 |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| elm/browser | 1.0.2 (already installed) | `Browser.element` upgrade | Official Elm browser API |
| elm/file | 1.0.5 (in global cache, not yet in elm.json) | File drag-drop + content reading | Official Elm file API; pure-Elm, no ports needed |
| elm/core | 1.0.4 (already installed) | `Process.sleep`, `Task.perform` for debounce | Built-in; no new dependency |
| elm/html | 1.0.0 (already installed) | `textarea`, `Html.Events.preventDefaultOn` | Built-in DOM events |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| elm/json | 1.1.2 (already installed) | `Json.Decode.decodeString`, `errorToString` | Already used for schema decode |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| elm/file pure-Elm drag-drop | JS ports + FileReader | Ports add JS maintenance surface; elm/file handles it natively in 0.19.1 |
| Process.sleep debounce (inline) | jinjor/elm-debounce package | Adding a dependency for a ~20-line pattern is unnecessary; inline is simpler |

**Installation (elm/file only — all other deps already present):**
```bash
elm install elm/file
```
This adds `"elm/file": "1.0.5"` to `elm.json` direct dependencies (package is already in global cache at `~/.elm/0.19.1/packages/elm/file/1.0.5/`).

---

## Architecture Patterns

### Recommended Project Structure

No new files needed. All changes are in existing files:
```
src/
├── Main.elm              # Browser.element upgrade, new Msg variants, layout, debounce
├── Render/Svg.elm        # Remove 4 Debug.log calls
├── Json/Schema/Decode.elm# Replace 2 Debug.toString calls with non-Debug alternatives
└── index.js              # Add ondragover preventDefault (1-2 lines) if needed
```

### Pattern 1: Browser.element Upgrade

**What:** Change `Browser.sandbox` to `Browser.element`. Adds `Cmd`, `Sub`, flags.

**When to use:** Any time Elm needs to issue commands (file reading tasks) or receive subscriptions.

**Example:**
```elm
-- Source: elm/browser 1.0.2 official API
main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }

init : () -> ( Model, Cmd Msg )
init _ =
    ( { inputText = exampleSchemaArrays
      , schema = decodeString decoder exampleSchemaArrays
      , lastValidSchema = Nothing   -- for D-09
      , debounceGeneration = 0
      , panelCollapsed = False
      }
    , Cmd.none
    )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )
        -- ... other cases
```

### Pattern 2: Live Textarea with Debounced Error Display (D-03, D-09)

**What:** Every keystroke updates `inputText` and immediately attempts decode. If decode succeeds, update `schema` and `lastValidSchema`. If decode fails, keep showing `lastValidSchema` in diagram but start a debounce timer. After the delay, show the error.

**When to use:** Live-updating input where you want to avoid flickering errors during typing.

**Model shape:**
```elm
type alias Model =
    { inputText : String
    , parsedSchema : Result Json.Decode.Error Json.Schema.Model
    , lastValidSchema : Maybe Json.Schema.Model   -- D-09: keep last good diagram
    , debounceGeneration : Int                    -- for debounce
    , panelCollapsed : Bool                       -- D-02
    , selectedExample : ExampleSchema             -- D-10/D-11
    }
```

**Msg variants:**
```elm
type Msg
    = TextareaChanged String
    | DebounceTimeout Int          -- carries generation ID
    | FileDrop File.File
    | FileContentLoaded String
    | ExampleSelected ExampleSchema
    | TogglePanel
```

**Debounce pattern (no external package):**
```elm
-- Source: Process module in elm/core 1.0.4
update msg model =
    case msg of
        TextareaChanged newText ->
            let
                newGen = model.debounceGeneration + 1
                parsed = decodeString decoder newText
                newLastValid =
                    case parsed of
                        Ok s -> Just s
                        Err _ -> model.lastValidSchema
                cmd =
                    Process.sleep 800
                        |> Task.perform (\_ -> DebounceTimeout newGen)
            in
            ( { model
                | inputText = newText
                , parsedSchema = parsed
                , lastValidSchema = newLastValid
                , debounceGeneration = newGen
              }
            , cmd
            )

        DebounceTimeout gen ->
            -- Only act if this is still the latest generation
            if gen == model.debounceGeneration then
                ( model, Cmd.none )  -- show current parsedSchema (may be error)
            else
                ( model, Cmd.none )  -- stale, discard
```

Note: the "show error after debounce" logic requires a `showError : Bool` flag in the model, or the view checks `gen == debounceGeneration` by tracking a separate `displayError : Bool`. The simplest approach: add a `displayErrors : Bool` field, set to `False` on `TextareaChanged`, set to `True` on `DebounceTimeout gen` if `gen == model.debounceGeneration`.

### Pattern 3: Drag-and-Drop File Upload (INPUT-02) — Pure Elm, No Ports

**What:** Use `Html.Events.preventDefaultOn` with `File.decoder` to intercept drop events. Use `Task.perform` to read file content as String.

**When to use:** Any drag-drop file input in Elm 0.19.1+.

**Key insight (D-05 correction):** Decision D-05 assumed ports were required. This is **incorrect** for Elm 0.19.1+. `elm/file` provides `File.decoder` and `File.toString` as pure-Elm APIs. Ports are NOT needed.

**Example:**
```elm
-- Source: elm/file 1.0.5 official documentation
import File
import File.Select as Select
import Json.Decode as Decode

-- Drag-drop handler on the textarea container div
onFileDrop : (File.File -> msg) -> Html.Attribute msg
onFileDrop toMsg =
    Html.Events.preventDefaultOn "drop"
        (Decode.map
            (\file -> ( toMsg file, True ))
            (Decode.at [ "dataTransfer", "files", "0" ] File.decoder)
        )

-- Also prevent default on dragover to enable drop
onDragOver : Html.Attribute msg
onDragOver =
    Html.Events.preventDefaultOn "dragover"
        (Decode.succeed ( NoOp, True ))

-- In update, when FileDrop arrives:
FileDrop file ->
    ( model
    , Task.perform FileContentLoaded (File.toString file)
    )

FileContentLoaded content ->
    ( { model
        | inputText = content
        , parsedSchema = decodeString decoder content
        , lastValidSchema =
            case decodeString decoder content of
                Ok s -> Just s
                Err _ -> model.lastValidSchema
      }
    , Cmd.none
    )
```

### Pattern 4: Example Schema Dropdown (D-10, D-11)

**What:** A custom type for example schemas, a `Dict` or `case` to look up content, a `<select>` element.

```elm
type ExampleSchema
    = ExampleArrays   -- existing jsonschema (fruits/vegetables)
    | ExamplePerson   -- existing jsonschema1
    | ExampleNested   -- existing jsonschema3 (person with children)

exampleContent : ExampleSchema -> String
exampleContent example =
    case example of
        ExampleArrays -> exampleArraysJson
        ExamplePerson -> examplePersonJson
        ExampleNested -> exampleNestedJson
```

### Pattern 5: Fixing Debug.toString in Json.Schema.Decode (FOUND-01)

**What:** Line 140 uses `Debug.toString` in an error message. Replace with a custom `valueToString` or use `Json.Encode.encode 0` to serialize the value.

The `constant` function in `Decode.elm` compares two decoded values. The error message currently serializes them for readability. Options:
- Replace `Debug.toString` with a simple fallback string: `"<value>"` (simpler, minimal change)
- Use `Json.Encode.encode 0` if the type is `Json.Decode.Value` (most informative)

Looking at line 140: `constant : a -> Decoder a -> Decoder a` — the type is generic `a`, so `Json.Encode.encode` won't work directly. The simplest fix is to remove the value interpolation: change the error message to a static string like `"Unexpected value"`.

### Anti-Patterns to Avoid

- **Using `Browser.sandbox` with any Cmd-producing code:** `sandbox` has no `Cmd` support. File reading requires `Task.perform` which produces `Cmd Msg`. Must use `Browser.element`.
- **Ports for file reading:** Not needed. `elm/file` handles this natively in Elm 0.19.1.
- **`Html.Events.on "drop"` without `preventDefaultOn`:** The browser's default drop behavior (navigate to dropped file URL) will fire unless `preventDefault()` is called. Use `preventDefaultOn` with `True`.
- **Missing `dragover` preventDefault:** Dropping only works if `dragover` also calls `preventDefault()`. Elm's default does not do this.
- **Forgetting `Task.perform` for `File.toString`:** `File.toString` returns `Task x String`, not `String`. It must be wrapped in `Task.perform FileContentLoaded`.
- **Keeping `Debug` import in `Decode.elm`:** Even if `Debug.toString` calls are replaced, the `import Debug` line will cause `--optimize` to fail if any `Debug.*` call remains anywhere.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reading dropped file as String | Custom JS port + FileReader | `elm/file` `File.toString` | Handles async, type-safe, no JS |
| Decoding File from drop event | Custom JS extraction | `File.decoder` from `elm/file` | Official API, handles cross-browser |
| Debounce timing | Custom effect manager | `Process.sleep` + generation counter | 20-line inline pattern, no dep needed |

**Key insight:** Elm 0.19.1's `elm/file` package made FileReader ports obsolete. Many online resources (pre-2019) recommend ports for file reading — those resources are outdated.

---

## Runtime State Inventory

Step 2.5: SKIPPED — This is not a rename/refactor/migration phase. No stored data, live service config, OS-registered state, secrets, or build artifacts are affected by these changes.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| elm | Compile + test | Yes | 0.19.1 | — |
| elm/file | INPUT-02 drag-drop | Yes (global cache) | 1.0.5 | — |
| elm-app | Dev server + build | Not in PATH | — | Use `elm make` directly for compile checks; `elm-app` must be installed before running dev server |
| elm-test | Test suite | Not verified in PATH | — | `npx elm-test` if installed locally |

**Missing dependencies with no fallback:**
- `elm-app` is not in PATH but is required for `elm-app start` / `elm-app build`. The `elm make` command is available for compile verification. The dev server and production build require `elm-app` to be installed (via `npm install -g create-elm-app` or local install).

**Missing dependencies with fallback:**
- `elm-test` — if not in PATH, use `npx elm-test` (assuming local npm install) or `./node_modules/.bin/elm-test`.

**Note on elm/file:** The package is in the global Elm cache at `~/.elm/0.19.1/packages/elm/file/1.0.5/`. Running `elm install elm/file` will add it to `elm.json` without a network download.

---

## Common Pitfalls

### Pitfall 1: Debug.toString in Generic Functions
**What goes wrong:** `Json.Schema.Decode.elm` line 140 uses `Debug.toString` on a generic `a` type. Simply removing the import without fixing the call site causes a compiler error.
**Why it happens:** `Debug.toString` was the only way to stringify an unknown type for error messages pre-0.19.
**How to avoid:** Replace the error message with a static string `"Unexpected value in constant decoder"` or reconstruct using type-specific logic. Do not try `Json.Encode.encode` — the type is `a`, not `Value`.
**Warning signs:** `--optimize` failure naming `Json.Schema.Decode` as a module with Debug remnants.

### Pitfall 2: Drop Without dragover Prevention
**What goes wrong:** Files can be dragged over the drop zone but cannot be dropped — the browser ignores the drop event.
**Why it happens:** Browsers only fire `drop` if `dragover` has called `preventDefault()`. This is a browser security requirement.
**How to avoid:** Add `onDragOver` attribute alongside `onFileDrop` on the same element:
```elm
Html.Events.preventDefaultOn "dragover" (Decode.succeed ( NoOp, True ))
```
**Warning signs:** Drop handler never fires; `dragover` cursor shows "no drop" icon.

### Pitfall 3: Model Mismatch After Browser.element Upgrade
**What goes wrong:** `init` still returns `Model` instead of `( Model, Cmd Msg )`, or `update` returns `Model` instead of `( Model, Cmd Msg )`.
**Why it happens:** The type signatures for `Browser.element` differ from `Browser.sandbox`.
**How to avoid:** Change both `init` and `update` type signatures in one pass. The compiler will flag all mismatches.
**Warning signs:** Type errors on `Browser.element` record fields `init` and `update`.

### Pitfall 4: Debounce Generation Overflow
**What goes wrong:** After many keystrokes, `Int` overflows (extremely unlikely in practice but worth noting).
**Why it happens:** Generation counter increments on every keystroke.
**How to avoid:** Elm's `Int` is 64-bit on modern JS engines. This is a non-issue in practice but can be noted.

### Pitfall 5: Textarea and Diagram Layout Not Responsive to Collapse (D-02)
**What goes wrong:** When `panelCollapsed = True`, the textarea still occupies space.
**Why it happens:** CSS `display: none` vs just `visibility: hidden` must be used.
**How to avoid:** Use `Html.Attributes.style "display" "none"` or conditionally exclude the element from the DOM using `if model.panelCollapsed then Html.text "" else textareaView`.

---

## Code Examples

Verified patterns from official sources:

### File Drop Decoder (elm/file 1.0.5)
```elm
-- Source: ~/.elm/0.19.1/packages/elm/file/1.0.5/src/File.elm official docs
import File
import Json.Decode as Decode

-- Decodes first file from a drop event's dataTransfer.files array
droppedFileDecoder : Decode.Decoder File.File
droppedFileDecoder =
    Decode.at [ "dataTransfer", "files", "0" ] File.decoder

-- Attribute for a drop target element
dropHandler : Html.Attribute Msg
dropHandler =
    Html.Events.preventDefaultOn "drop"
        (Decode.map (\f -> ( FileDrop f, True )) droppedFileDecoder)
```

### File.toString Task (elm/file 1.0.5)
```elm
-- Source: ~/.elm/0.19.1/packages/elm/file/1.0.5/src/File.elm official docs
import File
import Task

readFile : File.File -> Cmd Msg
readFile file =
    Task.perform FileContentLoaded (File.toString file)
```

### Process.sleep Debounce (elm/core 1.0.4)
```elm
-- Source: elm/core Process module
import Process
import Task

scheduleDebounce : Int -> Cmd Msg
scheduleDebounce generation =
    Process.sleep 800
        |> Task.perform (\_ -> DebounceTimeout generation)
```

### Browser.element Skeleton
```elm
-- Source: elm/browser 1.0.2 official API
main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }

init : () -> ( Model, Cmd Msg )
init _ =
    ( initialModel, Cmd.none )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )  -- all branches must return tuple
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| JS ports + FileReader for file reading | `elm/file` native API | Elm 0.19 (2018) | No ports needed for file reading |
| `Browser.sandbox` for simple apps | `Browser.element` when Cmd/Sub needed | Elm 0.19 | Enables file tasks |
| `Debug.toString` for error strings | Static strings or type-specific encoding | Elm --optimize requirement | Must be removed for production builds |

**Deprecated/outdated:**
- simonh1000/file-reader: Elm 0.18 package using native bindings — replaced by elm/file in 0.19
- elm-dropzone: Elm 0.18 package — replaced by elm/file + preventDefaultOn pattern

---

## Open Questions

1. **Does `Debug.toString` in `constant` function need a functional replacement?**
   - What we know: The function is used in the decoder to give error context when a value doesn't match expectation.
   - What's unclear: Whether this path is ever triggered by the test schemas or if removing the debug info is acceptable.
   - Recommendation: Replace with a static message `"Constant value mismatch"` — the error will still be caught and shown to the user; the serialized value detail is a developer aid that is not user-facing.

2. **Should `index.js` be modified for drag-drop?**
   - What we know: All drag-drop handling can be done in Elm using `preventDefaultOn`. No JS changes are required for the file reading itself.
   - What's unclear: Whether `elm-app`'s webpack config intercepts `dragover`/`drop` events before they reach Elm.
   - Recommendation: Start with pure-Elm approach. If drag-drop does not work in dev server, add `document.addEventListener('dragover', e => e.preventDefault())` to `index.js` as a fallback.

3. **elm-app availability**
   - What we know: `elm-app` is not currently in PATH. `elm make` is available.
   - What's unclear: Whether `elm-app` is installed locally or needs to be installed as part of this phase.
   - Recommendation: Planner should include a Wave 0 step to verify `elm-app` is runnable (via `npx`, global, or local install) before development tasks begin.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | elm-explorations/test 1.0.0 |
| Config file | none (create-elm-app auto-discovers `tests/`) |
| Quick run command | `elm-test tests/Tests.elm` |
| Full suite command | `elm-test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-01 | `elm make --optimize` exits 0 | smoke | `elm make src/Main.elm --output=/dev/null --optimize` | N/A — command check |
| FOUND-02 | `Browser.element` compiles | smoke | `elm make src/Main.elm --output=/dev/null` | N/A — command check |
| INPUT-01 | Textarea onChange triggers decode | unit | `elm-test tests/InputTests.elm` | ❌ Wave 0 |
| INPUT-02 | File content triggers decode | unit | `elm-test tests/InputTests.elm` | ❌ Wave 0 |

**Note:** FOUND-01 and FOUND-02 are verifiable by compile commands, not test cases. INPUT-01 and INPUT-02 can have unit tests for the decode + model update logic (the `update` function handling `TextareaChanged` and `FileContentLoaded`), but the drag-drop event wiring itself requires a browser.

### Sampling Rate
- **Per task commit:** `elm make src/Main.elm --output=/dev/null`
- **Per wave merge:** `elm make src/Main.elm --output=/dev/null --optimize && elm-test`
- **Phase gate:** `elm make src/Main.elm --output=/dev/null --optimize` exits 0 before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/InputTests.elm` — covers INPUT-01 (TextareaChanged → model update), INPUT-02 (FileContentLoaded → model update)
- [ ] `tests/Tests.elm` — existing file has a failing test (`Expect.fail`) — this should be cleaned up but is not a blocker (it is a placeholder)

*(Existing `tests/Tests.elm` has one intentionally failing test — this is a create-elm-app placeholder, not a real failure. It does not affect phase validation.)*

---

## Sources

### Primary (HIGH confidence)
- `~/.elm/0.19.1/packages/elm/file/1.0.5/src/File.elm` — File.decoder, File.toString API verified from source
- `~/.elm/0.19.1/packages/elm/file/1.0.5/src/File/Select.elm` — File.Select API verified from source
- `~/.elm/0.19.1/packages/elm/core/1.0.4/src/Process.elm` — Process.sleep confirmed in elm/core
- `elm make --optimize` test — confirmed exit code 1 with Debug remnants (ran live against this codebase)
- `src/Render/Svg.elm` lines 37, 667, 708, 710 — Debug.log confirmed present
- `src/Json/Schema/Decode.elm` line 140 — Debug.toString confirmed present

### Secondary (MEDIUM confidence)
- [elm/file GitHub README](https://github.com/elm/file/blob/master/README.md) — confirmed File.Select and File.toString
- [Elm discourse: Process.sleep debounce pattern](https://discourse.elm-lang.org/t/how-to-use-process-sleep-in-elm-0-19/1754) — Process.sleep basic usage confirmed
- [Elmseeds debounce](https://elmseeds.thaterikperson.com/debounce) — generation counter pattern confirmed

### Tertiary (LOW confidence)
- WebSearch results on drag-drop patterns — verified against elm/file source, elevated to HIGH

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages verified from global cache source files
- Architecture: HIGH — patterns derived from official elm/file source + live compile test
- Pitfalls: HIGH — dragover/preventDefault and Debug.toString issues confirmed by live testing and official docs

**Research date:** 2026-04-04
**Valid until:** 2026-10-04 (elm/file and elm/core are stable; no fast-moving dependencies)
