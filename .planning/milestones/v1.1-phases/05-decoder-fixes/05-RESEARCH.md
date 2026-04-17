# Phase 5: Decoder Fixes - Research

**Researched:** 2026-04-11
**Domain:** Elm JSON decoder extension, JSON Schema 2020-12 `$defs`, combined type+combinator schemas
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Normalize all definition keys to a common internal prefix. Strip the source prefix (`#/definitions/` or `#/$defs/`) during decode and store under a single internal format. Rewrite `$ref` values during decode to match the normalized keys.
- **D-02:** When a schema contains both `"definitions"` and `"$defs"`, merge both into a single Dict. This handles edge cases from schema generators that emit both fields.
- **D-03:** Add an optional `combinator : Maybe (CombinatorKind, List Schema)` field to typed schemas rather than creating new Schema union variants. `CombinatorKind` is a new type with `OneOfKind | AnyOfKind | AllOfKind`.
- **D-04:** Add the combinator field to all typed schemas (Object, Array, String, Integer, Number, Boolean, Null) via `BaseSchema`, not just Object. JSON Schema allows combinators on any type, and schema generators may produce them.
- **D-05:** The standalone `OneOf`/`AnyOf`/`AllOf` Schema variants remain for schemas that have a combinator without a type (pure combinator schemas).
- **D-06:** For combined type+combinator schemas, render properties first as normal children, then render the combinator variants below them with the combinator icon pill (`|1|`, `|o|`, `(&)`). Single parent node, two groups of children.
- **D-07:** Use the same "type pill then combinator children" pattern uniformly for all types, not just objects. Consistent rendering regardless of which typed schema carries the combinator.

### Claude's Discretion

- Exact normalization prefix for internal definition keys (could be bare names, `#/definitions/`, or a custom prefix)
- Decoder implementation details for detecting and extracting combinator fields from typed schemas
- How to order combinator children relative to regular properties in the y-coordinate layout
- Test schema selection for validating the fixes

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEC-01 | User can load JSON Schema 2020-12 documents using `$defs` and see definitions resolved correctly | `definitionsDecoder` extension to read `$defs` key + merge logic; `$ref` rewriting during decode |
| DEC-02 | User can load schemas with combined type + combinator (e.g., `type: "object"` with `oneOf`) and see both the object properties and combinator variants rendered | `BaseSchema` combinator field extension; decoder restructure; `viewSchema` combinator branch rendering |
</phase_requirements>

---

## Summary

This phase repairs two independent silent data-loss bugs in `src/Json/Schema/Decode.elm`. The decoder currently only reads `"definitions"` (draft-07) and ignores `"$defs"` (JSON Schema 2020-12), so any schema using the newer key produces an empty Definitions dict and all `$ref` lookups return Nothing. Separately, the `schemaDecoder` is a `oneOf` chain where type decoders use `withType` (requiring the `"type"` field) and combinator decoders use `required "oneOf"` etc. — meaning a schema with both `type` and `oneOf` matches the first applicable branch and drops the other. Both are classic "first-match-wins" decoder design problems in Elm.

The fixes are well-scoped. For DEC-01: extend `definitionsDecoder` to also probe `"$defs"`, prepend a chosen normalized prefix to those keys, merge the two dicts, and rewrite `$ref` values during decode so they resolve against the normalized keys. For DEC-02: add a `combinator : Maybe (CombinatorKind, List Schema)` field to `BaseSchema`, update every typed-schema constructor and constructor function accordingly, update each typed-schema decoder to also probe for `oneOf`/`anyOf`/`allOf` keys, and extend `viewSchema` to render combinator children after any properties/items.

The main coordination risk is the `BaseSchema` extensible record change — it touches `Json.Schema.elm` (type definitions), `Json.Schema/Decode.elm` (all typed decoders + constructors), and `Render/Svg.elm` (all `viewSchema` pattern match arms). Doing the type-system change first and following the compiler errors is the reliable path.

**Primary recommendation:** Start with the `BaseSchema` + `CombinatorKind` type changes so the compiler guides every downstream fix, then extend `definitionsDecoder` for `$defs`, then add tests before touching the renderer.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `NoRedInk/elm-json-decode-pipeline` | 1.0.0 | `optional`, `required`, `maybeOptional` helpers | Already in use; `optional` is key for adding combinator field |
| `elm/json` | 1.1.2 | `Json.Decode.oneOf`, `Json.Decode.map2`, `Dict` merging | Core decoder operations |
| `elm-explorations/test` | 2.0.0 | Unit tests for decoder round-trips | Already in use |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `elm/core Dict` | built-in | Dict.union / Dict.fromList for merging definitions | Merging `definitions` + `$defs` dicts |

No new packages needed. All tools for this phase are already declared in `elm.json`.

**Installation:** None required.

---

## Architecture Patterns

### Recommended Project Structure

No directory changes. All edits are within:
```
src/
├── Json/
│   ├── Schema.elm           -- Add CombinatorKind type; add combinator field to BaseSchema
│   └── Schema/
│       └── Decode.elm       -- Extend definitionsDecoder; restructure typed decoders
└── Render/
    └── Svg.elm              -- Extend viewSchema arms; add combinator rendering after properties
tests/
└── Tests.elm                -- Add decoder tests; add render helper tests
```

### Pattern 1: Normalized Definition Key Strategy

**What:** Strip source-specific prefixes (`#/definitions/` = 14 chars, `#/$defs/` = 8 chars) and store all keys under a single chosen internal prefix. Decision D-01 is to normalize to one format. The current code already uses `#/definitions/` as the internal prefix (stored keys start with `#/definitions/`). The simplest approach is to keep `#/definitions/` as the canonical internal prefix and rewrite `$defs` keys to `#/definitions/` format during decode.

**When to use:** Whenever a definition is decoded from either `"definitions"` or `"$defs"`.

**Example (current definitionsDecoder — only reads "definitions"):**
```elm
-- CURRENT (only handles "definitions"):
definitionsDecoder : Decoder Schema.Definitions
definitionsDecoder =
    field "definitions"
        (keyValuePairs schemaDecoder
            |> map (List.map (Tuple.mapFirst ((++) "#/definitions/")) >> Dict.fromList)
        )
        |> maybe
        |> map (Maybe.withDefault Dict.empty)
```

**Example (extended pattern for DEC-01):**
```elm
-- AFTER (handles both "definitions" and "$defs", merges them):
definitionsDecoder : Decoder Schema.Definitions
definitionsDecoder =
    let
        readDefs key =
            field key
                (keyValuePairs schemaDecoder
                    |> map (List.map (Tuple.mapFirst ((++) "#/definitions/")) >> Dict.fromList)
                )
                |> maybe
                |> map (Maybe.withDefault Dict.empty)
    in
    map2 Dict.union (readDefs "definitions") (readDefs "$defs")
```

`Dict.union` gives left-side precedence; if a key appears in both dicts, `"definitions"` wins. This satisfies D-02.

**Note on `$ref` rewriting:** `$ref` values that originally pointed at `"#/$defs/Foo"` need to resolve to the same normalized key `"#/definitions/Foo"`. The cleanest implementation is a `normalizeRef` helper called during decode of the `$ref` field:

```elm
normalizeRef : String -> String
normalizeRef ref =
    if String.startsWith "#/$defs/" ref then
        "#/definitions/" ++ String.dropLeft 8 ref
    else
        ref  -- already "#/definitions/..." or external, leave alone
```

Apply via `|> map normalizeRef` when decoding the `"$ref"` string field. The `extractRefName` function in `Render/Svg.elm` already does `String.dropLeft 14` (exactly the length of `"#/definitions/"`) — that function continues to work unchanged after normalization.

### Pattern 2: `BaseSchema` Combinator Field Extension

**What:** Add `combinator : Maybe (CombinatorKind, List Schema)` to `BaseSchema`. All existing typed schemas (`ObjectSchema`, `ArraySchema`, `StringSchema`, etc.) are aliases that extend `BaseSchema`, so they gain the field automatically.

**Current `BaseSchema`:**
```elm
type alias BaseSchema extras =
    { extras
        | title : Maybe String
        , description : Maybe String
        , examples : List Encode.Value
    }
```

**After (DEC-03 + DEC-04):**
```elm
type CombinatorKind
    = OneOfKind
    | AnyOfKind
    | AllOfKind

type alias BaseSchema extras =
    { extras
        | title : Maybe String
        , description : Maybe String
        , examples : List Encode.Value
        , combinator : Maybe ( CombinatorKind, List Schema )
    }
```

**Impact on constructor functions:** Every constructor (`object`, `array`, `string`, `integer`, `float`, `boolean`, `null`) must accept a `Maybe (CombinatorKind, List Schema)` argument and pass it into the record. The planner should structure the task so type changes happen first, then constructors, then decoders — the Elm compiler will report every call site that needs updating.

### Pattern 3: Decoder Restructure for Combined Schemas

**What:** Each typed decoder (e.g., the `object` arm in `schemaDecoder`) must probe for combinator fields after the type-specific fields. Use `optional` (from `elm-json-decode-pipeline`) to decode a `Maybe (CombinatorKind, List Schema)` value.

**The challenge:** A single `optional` field cannot produce `Maybe (CombinatorKind, List Schema)` directly because the kind depends on which key is present (`oneOf`, `anyOf`, or `allOf`). A helper decoder is needed:

```elm
combinatorDecoder : Decoder (Maybe ( Schema.CombinatorKind, List Schema ))
combinatorDecoder =
    oneOf
        [ field "oneOf" (list schemaDecoder) |> map (\s -> Just ( Schema.OneOfKind, s ))
        , field "anyOf" (list schemaDecoder) |> map (\s -> Just ( Schema.AnyOfKind, s ))
        , field "allOf" (list schemaDecoder) |> map (\s -> Just ( Schema.AllOfKind, s ))
        , succeed Nothing
        ]
```

This is used with `andMap` (pipeline) or `andThen` when building each typed decoder.

**Decoder arm order:** The current `schemaDecoder` `oneOf` chain must be reviewed. A schema with `{"type":"object","oneOf":[...]}` currently matches the `object` arm (type field present) and `oneOf` sub-schemas are lost. After the fix, the object arm itself captures the combinator field — no ordering change is needed.

The standalone `OneOf`/`AnyOf`/`AllOf` decoders (D-05) remain for schemas with no `type` field. Their position in the `oneOf` chain below the typed decoders is correct because `withType` fails for type-less schemas.

### Pattern 4: Rendering Combined Schemas (D-06, D-07)

**What:** In `viewSchema`, after rendering the typed node and its normal children (properties/items), check `schema.combinator` and if `Just (kind, subSchemas)`, render a combinator pill + child branches using the existing `viewMulti` logic.

**Coordinate threading:** `viewProperties` returns `(List (Svg msg), Coordinates)` where the second element is `(maxWidth, bottomY)`. The combinator group starts at `(originalX + 10, bottomY + ySpace)` where `originalX` is the parent node's right edge and `ySpace = 10`.

**Existing `viewMulti` is reusable:** It renders the pill (`roundRect icon`) and calls `viewItems` for the sub-schemas. However, `viewMulti` currently takes `(String -> msg)` toggleMsg and path, wraps the whole thing in a clickable group. For the embedded combinator case, the combinator pill should be at the sibling/child level, not wrapping the parent. The cleanest approach is to call `viewMulti` as a child positioned below the last property, connecting it with `connectorPath` from the parent's right edge. `viewMulti` returns `(Svg msg, Dimensions)` — plug those dimensions into the parent's final dimension calculation with `Basics.max`.

**Y-offset accumulation example for Object with combinator:**
```
parent object pill    (x, y)          → rightEdge w, bottom h
  property 1          (w+10, y)
  property 2          (w+10, py1+10)
  ...
  combinator pill     (w+10, lastPropBottom+10)  ← new
    oneOf variant 1   (combW+10, y)
    oneOf variant 2   (combW+10, v1Bottom+10)
```

### Anti-Patterns to Avoid

- **Parallel `oneOf` chain with a combined-schema arm:** Adding a new `object+oneOf` decoder variant to the existing `schemaDecoder` `oneOf` chain causes order-sensitivity issues and code duplication. The correct fix is to add the combinator field directly inside each typed arm.
- **Storing `$defs` keys under `#/$defs/` prefix internally:** Would require updating `extractRefName` (currently hardcodes 14-char drop) and every test that references `"#/definitions/"`. Keep the canonical prefix as `#/definitions/` and rewrite at decode time.
- **Skipping `normalizeRef` for `$ref` values:** If a schema uses `"$defs"` and `$ref` values like `"#/$defs/Foo"`, lookup in the normalized dict will silently fail. The normalization must happen on the ref string during decode, not just on the key during storage.
- **Adding `combinator` only to `ObjectSchema`:** D-04 explicitly requires it on all typed schemas via `BaseSchema`. Restricting to `ObjectSchema` would require per-type special cases in the renderer later.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dict merging | Custom merge loop | `Dict.union` (elm/core) | Left-biased merge is exactly D-02 semantics |
| Optional JSON field probe | Manual `value` decode + inspection | `Json.Decode.oneOf [field "oneOf" ..., succeed Nothing]` | Idiomatic; composes correctly with pipeline |
| Test schema construction | Inline JSON strings in test bodies | Dedicated `let` helpers or top-level constants | Keeps tests readable; reuse across multiple assertions |

**Key insight:** Elm's `Dict.union` handles the merge, and `Json.Decode.oneOf` with `succeed Nothing` fallback handles optional-key probing — no custom logic needed for either.

---

## Common Pitfalls

### Pitfall 1: `BaseSchema` Change Breaks All Typed Constructor Functions

**What goes wrong:** Adding `combinator` to `BaseSchema` makes every record literal in `Json.Schema.elm` (`object`, `array`, `string`, etc.) a type error because the field is missing.

**Why it happens:** Elm extensible records enforce that all declared fields are present in every record literal.

**How to avoid:** Update all constructor functions to accept and pass the combinator value in the same commit as the type change. The compiler will list every incomplete record.

**Warning signs:** Compile errors mentioning "missing field `combinator`" in `Json.Schema.elm`.

### Pitfall 2: `extractRefName` Length Assumption

**What goes wrong:** `extractRefName` does `String.dropLeft 14` — exactly the length of `"#/definitions/"`. If `$defs` refs are stored under `"#/$defs/"` (8 chars) instead of being normalized, `extractRefName` drops the wrong number of characters and produces garbled names.

**Why it happens:** The 14-char hardcode was written when only `"#/definitions/"` existed.

**How to avoid:** Always normalize `$ref` values to `"#/definitions/"` during decode (D-01). Then `extractRefName` works unchanged. Tests in `RenderHelpers.elm` (`extractRefName` suite) will catch regressions.

**Warning signs:** Definition names appearing as `s/Foo` or similar substrings.

### Pitfall 3: `viewMulti` Signature Mismatch When Rendering Embedded Combinator

**What goes wrong:** `viewMulti` currently ignores its `Maybe Name` argument (pattern-matches with `_`). When called for an embedded combinator, the caller might pass the parent schema name expecting it to propagate — it won't.

**Why it happens:** The `Maybe Name` parameter in `viewMulti` was stubbed out; the combinator pill uses its `icon` string as the label.

**How to avoid:** When calling `viewMulti` for embedded combinators, pass `Nothing` for name (consistent with current behavior). The icon string (`|1|`, `|o|`, `(&)`) is the visual label. No change to `viewMulti` signature needed.

**Warning signs:** Unexpected text appearing inside combinator pills.

### Pitfall 4: Pure Combinator Schemas Still Matched Before Typed Decoders

**What goes wrong:** If the standalone `OneOf`/`AnyOf`/`AllOf` decoder arms appear before the typed arms in `schemaDecoder`'s `oneOf` chain, a `{"type":"object","oneOf":[...]}` schema could match the combinator arm and lose the type information.

**Why it happens:** Elm `oneOf` uses first-match-wins.

**How to avoid:** Typed arms (using `withType`) should remain before standalone combinator arms. The `withType` helper fails on schemas without a `type` field, so it will never accidentally consume a pure combinator schema.

**Warning signs:** An object schema with properties and `oneOf` renders only the combinator pill, not the object node.

### Pitfall 5: Y-coordinate Double-Counting in Combined Object+Combinator Layout

**What goes wrong:** When appending the combinator group below properties, using the object pill's bottom `h` as the starting y for the combinator (instead of the properties group's bottom `ph`) results in the combinator overlapping properties.

**Why it happens:** The `viewProperties` bottom y (`ph`) tracks the actual rendered height including all children. The object pill height (`h = pillHeight + y`) is just the header pill.

**How to avoid:** Use `ph` (bottom of last property) as the y-input for the combinator group, not `h`. The `toSvgCoordsTuple` call at the end should use `Basics.max` across `pw`, `combW`, and heights from all groups.

---

## Code Examples

### How `Dict.union` Works for D-02 Merge

```elm
-- Source: elm/core Dict documentation
-- Dict.union keeps left-side values for duplicate keys
Dict.union
    (Dict.fromList [("#/definitions/Foo", fooSchema), ("#/definitions/Bar", barSchema)])
    (Dict.fromList [("#/definitions/Foo", fooSchema2), ("#/definitions/Baz", bazSchema)])
-- Result: {"#/definitions/Foo" -> fooSchema, "#/definitions/Bar" -> barSchema, "#/definitions/Baz" -> bazSchema}
-- "Foo" from definitions wins over "Foo" from $defs
```

### `combinatorDecoder` Helper

```elm
combinatorDecoder : Decoder (Maybe ( Schema.CombinatorKind, List Schema ))
combinatorDecoder =
    oneOf
        [ field "oneOf" (list schemaDecoder) |> map (\s -> Just ( Schema.OneOfKind, s ))
        , field "anyOf" (list schemaDecoder) |> map (\s -> Just ( Schema.AnyOfKind, s ))
        , field "allOf" (list schemaDecoder) |> map (\s -> Just ( Schema.AllOfKind, s ))
        , succeed Nothing
        ]
```

This must be placed after `schemaDecoder` is defined (or the `lazy` wrapper handles the circular reference). In practice, it should sit inside the `lazy (\_ -> ...)` block or reference `schemaDecoder` directly since `schemaDecoder` is already `lazy`.

### `normalizeRef` Helper

```elm
normalizeRef : String -> String
normalizeRef ref =
    if String.startsWith "#/$defs/" ref then
        "#/definitions/" ++ String.dropLeft 8 ref
    else
        ref
```

Applied in the `$ref` decoder arm:
```elm
, succeed Schema.reference
    |> maybeOptional "title" string
    |> maybeOptional "description" string
    |> required "$ref" (string |> map normalizeRef)
    |> optional "examples" (list value) []
```

### Test Schema for DEC-01 (`$defs` round-trip)

```elm
defs2020Schema : String
defs2020Schema =
    """
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "address": { "$ref": "#/$defs/Address" }
  },
  "$defs": {
    "Address": {
      "type": "object",
      "properties": {
        "street": { "type": "string" },
        "city": { "type": "string" }
      }
    }
  }
}
"""
```

Expected after decode: `definitions` Dict contains `"#/definitions/Address"` key; the `$ref` value in the `address` property is `"#/definitions/Address"`.

### Test Schema for DEC-02 (combined type+combinator)

```elm
combinedObjectSchema : String
combinedObjectSchema =
    """
{
  "type": "object",
  "properties": {
    "name": { "type": "string" }
  },
  "oneOf": [
    { "required": ["name"] },
    { "required": [] }
  ]
}
"""
```

Expected after decode: Schema is `Object {..., combinator = Just (OneOfKind, [...])}` — not `OneOf`.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `definitions` (draft-07) | `$defs` (2020-12) | JSON Schema 2020-12 release | Must support both during decode; `$defs` is the canonical key in 2020-12 but `definitions` still widely used |
| `oneOf`/`anyOf`/`allOf` as top-level only | Combinators as peer to `type` | Common schema generator pattern (TypeBox, Zod) | Combined schemas must be decoded as a single typed node with embedded combinator |

**Deprecated/outdated:**

- `"definitions"` key: Still valid in draft-07 and widely used, but `"$defs"` is the preferred key in 2020-12 onwards. Both must be supported.

---

## Open Questions

1. **Normalization prefix choice (Claude's discretion)**
   - What we know: Current code stores keys as `"#/definitions/Foo"`. The `extractRefName` function hardcodes `String.dropLeft 14`. Tests in `RenderHelpers.elm` assert against `"#/definitions/"` prefix format.
   - What's unclear: Whether to keep `"#/definitions/"` as the internal canonical prefix (minimal change to renderer + tests) or switch to bare names (simpler, shorter keys).
   - Recommendation: Keep `"#/definitions/"` as the canonical prefix. `extractRefName` and existing tests continue to work unchanged. Switching to bare names would require updating the renderer, tests, and potentially introduce regressions in an area not targeted by this phase.

2. **`combinatorDecoder` placement inside `lazy` block**
   - What we know: `schemaDecoder` uses `lazy` to handle recursive schemas. `combinatorDecoder` calls `list schemaDecoder` (recursive).
   - What's unclear: Whether `combinatorDecoder` should be a top-level function or defined inside the `lazy` block.
   - Recommendation: Define `combinatorDecoder` as a top-level function that references `schemaDecoder` directly. Since `schemaDecoder` is already wrapped in `lazy`, the mutual recursion is handled. This keeps the code readable.

3. **Example schema selection for testing TypeBox/Zod output**
   - What we know: The success criteria mention TypeBox and Zod-generated schemas. These tend to use `$defs` and combined type+combinator patterns.
   - What's unclear: Whether to add a new built-in example to `Main.elm` or rely on the paste/upload workflow for validation.
   - Recommendation: Add a `ExampleTypeBox` example to `Main.elm` inline JSON string — gives a built-in quick test case and demonstrates the feature to new users.

---

## Environment Availability

Step 2.6: Elm compiler and elm-test are the only runtime dependencies.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| elm 0.19.1 | Compilation | assumed yes (existing project) | 0.19.1 | — |
| elm-test | `elm-test` command | yes | 0.19.1-revision17 | — |

Both confirmed by the test run output (`elm-test 0.19.1-revision17`, 24 tests passed in 147 ms).

---

## Validation Architecture

> `workflow.nyquist_validation` key is absent from `.planning/config.json` — treated as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | elm-explorations/test 2.0.0 |
| Config file | `elm.json` (test-dependencies section) |
| Quick run command | `elm-test` |
| Full suite command | `elm-test` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEC-01 | `$defs` decoded into `definitions` Dict with normalized keys | unit | `elm-test --watch` / `elm-test` | ❌ Wave 0 |
| DEC-01 | `$ref` values pointing to `#/$defs/` normalized to `#/definitions/` | unit | `elm-test` | ❌ Wave 0 |
| DEC-01 | Both `definitions` and `$defs` present: merged, no key loss | unit | `elm-test` | ❌ Wave 0 |
| DEC-02 | `{"type":"object","oneOf":[...]}` decodes as `Object` with `combinator = Just (OneOfKind, ...)` | unit | `elm-test` | ❌ Wave 0 |
| DEC-02 | Pure combinator `{"oneOf":[...]}` still decodes as `OneOf` (no type field) | unit | `elm-test` | ❌ Wave 0 |
| DEC-02 | `extractRefName` still strips `#/definitions/` correctly after normalization | unit | `elm-test` | ✅ (existing test) |

### Sampling Rate

- **Per task commit:** `elm-test`
- **Per wave merge:** `elm-test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/DecoderTests.elm` — covers DEC-01 (`$defs` decode, ref normalization, merge) and DEC-02 (combined schema decode, pure combinator unchanged)
- [ ] No framework install needed — elm-explorations/test 2.0.0 already declared in elm.json

---

## Sources

### Primary (HIGH confidence)

- Direct code reading: `src/Json/Schema.elm` — complete Schema type, BaseSchema, all aliases
- Direct code reading: `src/Json/Schema/Decode.elm` — definitionsDecoder (line 22-29), schemaDecoder (line 32-117), withType helper
- Direct code reading: `src/Render/Svg.elm` — viewSchema (line 201), viewMulti (line 308), extractRefName (line 826-828)
- Direct code reading: `tests/Tests.elm`, `tests/RenderHelpers.elm` — existing test coverage
- Direct code reading: `elm.json` — confirmed package versions
- Test run output: `elm-test 0.19.1-revision17`, 24 tests passed

### Secondary (MEDIUM confidence)

- JSON Schema 2020-12 specification: `$defs` replaces `definitions` as the canonical key; both may appear in practice
- TypeBox/Zod output patterns: These generators emit `$defs` and frequently combine `type` with `oneOf`/`anyOf` for discriminated unions

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all libraries already in elm.json; no new dependencies
- Architecture: HIGH — all integration points identified from direct code reading; patterns derived from existing working code in the same modules
- Pitfalls: HIGH — pitfalls derived from direct analysis of the existing decoder chain and renderer coordinate threading

**Research date:** 2026-04-11
**Valid until:** Stable — Elm 0.19.1 has not had breaking changes since 2019; elm-json-decode-pipeline 1.0.0 API is stable
