# Phase 5: Decoder Fixes - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the JSON Schema decoder to correctly handle modern schemas: support `$defs` (JSON Schema 2020-12) alongside `definitions` (draft-07), and decode schemas that combine a typed schema (e.g., `type: "object"`) with combinator keywords (`oneOf`/`anyOf`/`allOf`). Both issues currently cause silent data loss where definitions or combinator variants are dropped.

</domain>

<decisions>
## Implementation Decisions

### $defs Key Resolution
- **D-01:** Normalize all definition keys to a common internal prefix. Strip the source prefix (`#/definitions/` or `#/$defs/`) during decode and store under a single internal format. Rewrite `$ref` values during decode to match the normalized keys.
- **D-02:** When a schema contains both `"definitions"` and `"$defs"`, merge both into a single Dict. This handles edge cases from schema generators that emit both fields.

### Combined Type+Combinator Modeling
- **D-03:** Add an optional `combinator : Maybe (CombinatorKind, List Schema)` field to typed schemas rather than creating new Schema union variants. `CombinatorKind` is a new type with `OneOfKind | AnyOfKind | AllOfKind`.
- **D-04:** Add the combinator field to all typed schemas (Object, Array, String, Integer, Number, Boolean, Null) via `BaseSchema`, not just Object. JSON Schema allows combinators on any type, and schema generators may produce them.
- **D-05:** The standalone `OneOf`/`AnyOf`/`AllOf` Schema variants remain for schemas that have a combinator without a type (pure combinator schemas).

### Rendering Combined Schemas
- **D-06:** For combined type+combinator schemas, render properties first as normal children, then render the combinator variants below them with the combinator icon pill (`|1|`, `|o|`, `(&)`). Single parent node, two groups of children.
- **D-07:** Use the same "type pill then combinator children" pattern uniformly for all types, not just objects. Consistent rendering regardless of which typed schema carries the combinator.

### Claude's Discretion
- Exact normalization prefix for internal definition keys (could be bare names, `#/definitions/`, or a custom prefix)
- Decoder implementation details for detecting and extracting combinator fields from typed schemas
- How to order combinator children relative to regular properties in the y-coordinate layout
- Test schema selection for validating the fixes

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project & Requirements
- `.planning/PROJECT.md` -- Project vision, constraints (Elm 0.19.1, SVG only, client-only)
- `.planning/REQUIREMENTS.md` -- DEC-01, DEC-02 are the requirements for this phase
- `.planning/ROADMAP.md` Phase 5 section -- Success criteria (3 items)

### Prior Phase Context
- `.planning/phases/04-visual-polish/04-CONTEXT.md` -- Phase 4 decisions (connector lines, $ref dashed borders)

### Existing Code (critical for this phase)
- `src/Json/Schema.elm` -- Schema union type, ObjectSchema/BaseSchema type aliases, Definitions type alias
- `src/Json/Schema/Decode.elm` -- `definitionsDecoder` (line 22, only reads "definitions"), `schemaDecoder` (line 32, oneOf decoder chain where first match wins), `withType` helper
- `src/Render/Svg.elm` -- `viewSchema` (line 202, pattern match on Schema variants), `viewMulti` (line 309, combinator rendering), `viewProperties`/`viewItems` for child layout

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `viewMulti` at `Render/Svg.elm:309` -- Already renders combinator pill + child branches. Can be reused for the combinator portion of combined schemas.
- `viewProperties` at `Render/Svg.elm:76` -- Renders object properties with y-offset accumulation. The combinator group would be appended after properties in the y-coordinate space.
- `definitionsDecoder` at `Decode.elm:22` -- Current definitions decoder. Needs to be extended to also read `$defs` and merge results.

### Established Patterns
- Coordinate-threading: every view function returns `(Svg msg, Dimensions)` -- combinator rendering after properties needs to use the accumulated y-offset from properties as its starting position.
- `BaseSchema` extensible record pattern -- the combinator field can be added here so all typed schemas inherit it.
- Elm `oneOf` decoder chain -- the decoder order matters; combined schemas need to be detected before falling through to pure type or pure combinator decoders.

### Integration Points
- `schemaDecoder` needs restructuring: typed schema decoders must also probe for combinator fields, populate the new `combinator` field
- `viewSchema` pattern match on `Object`/`Array`/etc. must check the `combinator` field and render combinator children if present
- `definitionsDecoder` needs a parallel `$defs` decoder with merge logic

</code_context>

<specifics>
## Specific Ideas

- The "properties first, then combinator branches" layout means the combinator pill appears as a pseudo-child after the last property, visually grouping the two aspects of the schema
- TypeBox and Zod-generated schemas are specifically called out in the success criteria -- these should be tested

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 05-decoder-fixes*
*Context gathered: 2026-04-09*
