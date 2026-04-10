# Phase 5: Decoder Fixes - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-04-09
**Phase:** 05-decoder-fixes
**Areas discussed:** $defs key resolution, Combined type+combinator modeling, Rendering combined schemas

---

## $defs Key Resolution

### Q1: How should we normalize definition keys from both "definitions" and "$defs"?

| Option | Description | Selected |
|--------|-------------|----------|
| Normalize to common prefix | Strip the source prefix and store all keys under a single internal prefix. Rewrite $ref values during decode to match. | :heavy_check_mark: |
| Preserve original prefixes | Store #/definitions/Foo and #/$defs/Foo as-is. $ref lookup naturally matches since refs use the same prefix. | |
| You decide | Claude picks the approach that's cleanest for the codebase | |

**User's choice:** Normalize to common prefix (Recommended)
**Notes:** None

### Q2: Should schemas containing both "definitions" and "$defs" merge them?

| Option | Description | Selected |
|--------|-------------|----------|
| Merge both into one Dict | If a schema has both fields, combine all entries. | :heavy_check_mark: |
| Prefer $defs, ignore definitions if both present | 2020-12 takes precedence. Simpler but could drop draft-07 definitions. | |
| You decide | Claude picks based on what real-world schemas look like | |

**User's choice:** Merge both into one Dict (Recommended)
**Notes:** None

---

## Combined Type+Combinator Modeling

### Q1: How should we model schemas that combine type properties with combinators?

| Option | Description | Selected |
|--------|-------------|----------|
| Add combinator field to typed schemas | Add optional combinator : Maybe (CombinatorKind, List Schema) to typed schemas. Keeps existing Schema union type mostly intact. | :heavy_check_mark: |
| New combined variant | Add new Schema variants like ObjectOneOf for each combination. Explicit but combinatorial explosion risk. | |
| Wrapper variant | Single Combined Schema CombinatorKind (List Schema) variant wrapping any typed schema. | |
| You decide | Claude picks the cleanest approach for the Elm type system | |

**User's choice:** Add combinator field to typed schemas (Recommended)
**Notes:** User selected based on the preview showing the type alias with optional combinator field

### Q2: Should the combinator field be added to all typed schemas or just Object?

| Option | Description | Selected |
|--------|-------------|----------|
| All typed schemas | JSON Schema allows combinators on any type. Adding to BaseSchema covers everything uniformly. | :heavy_check_mark: |
| Object only | In practice combined type+combinator almost always happens on objects. Simpler, extend later if needed. | |
| You decide | Claude picks based on real-world schema patterns | |

**User's choice:** All typed schemas (Recommended)
**Notes:** None

---

## Rendering Combined Schemas

### Q1: How should a combined type+combinator node appear in the diagram?

| Option | Description | Selected |
|--------|-------------|----------|
| Properties first, then combinator branches | Render object properties as children first, then combinator variants below with combinator icon. Single parent, two groups. | :heavy_check_mark: |
| Side-by-side sections | Properties branch right as usual. Combinator variants branch from separate pill below parent. Two visual groups at same level. | |
| You decide | Claude picks the clearest visual representation | |

**User's choice:** Properties first, then combinator branches (Recommended)
**Notes:** User selected based on the ASCII preview showing the tree layout

### Q2: When the combinator is on a non-object type, how should it render?

| Option | Description | Selected |
|--------|-------------|----------|
| Same pattern -- type pill then combinator children | Consistent rendering: show typed node, then combinator variants as children below. Uniform for all types. | :heavy_check_mark: |
| You decide | Claude picks based on what looks reasonable for each type | |
| Skip -- object-only for now | Only render combinators on object schemas. Other types with combinators render without combinator. | |

**User's choice:** Same pattern -- type pill then combinator children
**Notes:** None

---

## Claude's Discretion

- Exact normalization prefix for internal definition keys
- Decoder implementation details for detecting combinator fields
- Y-coordinate ordering of combinator children relative to properties
- Test schema selection

## Deferred Ideas

None -- discussion stayed within phase scope
