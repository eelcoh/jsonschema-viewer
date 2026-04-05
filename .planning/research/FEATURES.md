# Feature Landscape

**Domain:** Interactive JSON Schema SVG diagram viewer
**Researched:** 2026-04-03
**Confidence:** MEDIUM — Based on strong training knowledge of XMLSpy, Liquid XML Studio, and Oxygen XML Editor diagram views; no live web verification possible due to tool restrictions. Core UX patterns in these tools are well-established and stable.

---

## How XML Schema Diagram Tools Visualize Schemas

This section informs what "table stakes" means for a diagram viewer, drawn from how Altova XMLSpy, Liquid XML Studio, and Oxygen XML Editor approach schema visualization.

**Altova XMLSpy** renders XSD as a tree diagram with box-shaped nodes. Each element shows its name, type annotation, and cardinality (minOccurs/maxOccurs) on connector lines. Objects/complexTypes are expandable — clicking a node with children shows a toggle arrow; the expanded state shows child elements as child boxes connected by horizontal or vertical lines. `$ref`-equivalent constructs (xsd:element ref=) are shown inline but visually distinguished (typically dashed border or different color). Compositor nodes (sequence, choice, all) appear as distinct intermediate nodes with their own visual treatment.

**Liquid XML Studio** uses a similar tree structure but leans more heavily on color to encode type information — different colors for element vs attribute vs simple type vs complex type. The layout is vertical (parent above children) with horizontal connectors. Cardinality annotations are displayed adjacent to connectors. Nodes can be collapsed to a stub showing just the name and a "..." indicator.

**Oxygen XML Editor** has both a "full" diagram mode and a compact mode. In the diagram, each element shows name, type, and has expand/collapse affordances. `$ref`-style references resolve inline — you see the referenced type's structure directly in the diagram, though the reference node is marked distinctly (e.g., with italic or a reference icon). Combinators (choice/sequence/all) are shown as intermediate nodes with a visual label. The tool supports pan and zoom on the diagram canvas.

**Common patterns across all three:**
- Nodes are individually collapsible/expandable
- Required vs optional fields are visually distinguished (bold name, asterisk, or solid vs dashed border)
- Type icons or color-coded labels are on every node
- Connector lines link parent to children — horizontal lines run to a vertical bar, which drops to each child
- Cardinality (0..1, 1..*, etc.) is annotated on connector lines or in the node
- $ref targets resolve inline (not just a label) and are marked as references
- Combinators (oneOf/anyOf/allOf equivalent) are shown as distinct intermediary nodes

---

## Table Stakes

Features users expect from a JSON Schema diagram viewer. Missing = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Codebase Dependency | Notes |
|---------|--------------|------------|---------------------|-------|
| User can paste their own JSON Schema | Without this, the app has zero utility for real users | Low | Requires `Browser.element` or `Browser.document` upgrade from `Browser.sandbox`; add `Msg` for text input and `textarea` HTML | Must handle parse errors gracefully with a readable message |
| All schema nodes render with type icons | Already partially done; users need to visually parse type at a glance | Low | `iconRect` / `iconGraph` already implemented for most types; `INull` icon uses `iconGeneric` but is not wired into `viewSchema`'s Null branch — fix needed | Current `Null` branch calls `viewMaybeTitle` which calls `roundRect`, bypassing the icon system |
| Required vs optional property distinction | Users need to know which fields are mandatory | Low | `ObjectProperty` union type (`Required`/`Optional`) already decoded correctly; just not visually distinct in renderer — `viewProperty` treats both identically | Add visual marker (e.g., bold name or asterisk suffix) in `viewProperty` |
| Connector lines between parent and child nodes | Without connectors, the spatial relationship between nodes is ambiguous | Medium | SVG line drawing needed; coordinates already tracked via `(Svg msg, Dimensions)` return; need to thread connector drawing into `viewProperties` and `viewItems` | Horizontal line from parent right edge to child left edge; requires knowing child Y after layout |
| $ref nodes expand inline to show referenced schema | A $ref that shows only a label is not a diagram — it's incomplete | High | `viewSchema`'s `Ref` branch looks up `Dict.get ref defs` but renders only `roundRect ref` instead of recursing into the resolved schema; fix requires guarding against infinite recursion (circular refs) | Circular ref detection needed — track a `Set String` of currently-expanded refs |
| Combinator schemas (oneOf/anyOf/allOf) render their sub-schemas | A `oneOf` showing only "|1|" with no sub-schemas is meaningless | Medium | `viewMulti` passes schemas to `viewItems` — this is implemented but sub-schemas render as `viewArrayItem` (anonymous, no name label) which is correct; main issue is the intermediate node icon is text-only "|1|", "|o|", "(&)" — acceptable for now but visually weak | Works structurally; icon improvement is a differentiator |
| Fixed SVG viewport that scrolls or grows | Current hard-coded `520x520` viewport clips any real-world schema | Medium | `Render.Svg.view` has hardcoded `"520"` width/height and `viewBox`; needs dynamic sizing based on computed dimensions from `viewSchema` return value | The `(Svg msg, Dimensions)` threading already computes final dimensions — use them for viewBox |
| Error display for invalid JSON Schema input | Users will paste broken JSON; a blank screen or crash is confusing | Low | `Main.elm` already handles `Result Json.Decode.Error` but only shows `Json.Decode.errorToString` in a div — acceptable for MVP; could be improved | Already basically working |

---

## Differentiators

Features that set this product apart. Not expected, but valued when present.

| Feature | Value Proposition | Complexity | Codebase Dependency | Notes |
|---------|-------------------|------------|---------------------|-------|
| Cardinality annotations on connectors | Makes array bounds (minItems/maxItems) and object constraints (minProperties/maxProperties) visible at a glance | Low | `ArraySchema` has `minItems`/`maxItems`; `ObjectSchema` has `minProperties`/`maxProperties`; `IntegerSchema`/`NumberSchema` have `minimum`/`maximum` — all already decoded; just not rendered | Show as "0..*" style labels adjacent to connector lines |
| Collapse/expand individual nodes | Essential for navigating large real-world schemas (e.g., OpenAPI component schemas with 20+ properties) | High | Requires upgrade from `Browser.sandbox` to `Browser.element`; add expanded/collapsed state to `Model` as `Set NodeId`; each node needs a stable ID (path-based string); click handler on node toggle | This is the highest-value interactive feature and enables using the tool on real schemas |
| Description tooltip or inline display | `description` is decoded on every schema type but never shown; it contains the most useful human-readable info | Low | `BaseSchema` already stores `description : Maybe String` on all types; just needs a render path | Show as SVG `<title>` element (native SVG tooltip on hover) for low-effort implementation |
| Distinct visual style for $ref nodes vs inline nodes | Helps users distinguish "this is a reference" from "this is a literal type definition" | Low | Already have `IRef` icon variant; add a visual treatment like dashed border on the `iconRect` rect element | Currently the IRef icon just prepends "*" to the ref name — a dashed border would be clearer |
| Enum value display | String/integer fields with `enum` values are common; showing the allowed values helps users understand the schema contract | Medium | `WithEnumSchema` already decoded on `String`, `Integer`, `Number`, `Boolean` types; not rendered | Show as small list below the node or in a tooltip |
| Format annotation on string nodes | `format` (date-time, email, uri, etc.) is decoded as `StringFormat` but not rendered | Low | `StringSchema.format : Maybe StringFormat` already decoded; just needs a render path — show format tag in the node | Very easy win given decoding is done |
| Pan and zoom on the diagram canvas | Real-world schemas are large; users need to navigate the diagram spatially | High | Requires JS interop via ports (Pan/zoom is hard to do in pure Elm SVG without `onMouseMove` coordinate tracking or a transform matrix); or use SVG `viewBox` manipulation with Elm events | This is the most complex feature — defer to post-MVP; scroll is a reasonable interim solution |
| "Expand all" / "Collapse all" controls | Convenience when you want an overview or full detail | Low | Depends on expand/collapse being implemented first; then it's just a button that sets all node IDs to expanded or empty set | Depends on collapse/expand feature |

---

## Anti-Features

Features to explicitly NOT build for this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Schema editing / authoring | Out of scope per PROJECT.md; adds massive complexity (two-way binding between diagram and JSON text) | Keep the textarea read-only; it's a viewer not an editor |
| Schema validation (validating data against schema) | A completely different problem domain; no user need stated | Ignore; link to ajv or similar if a user asks |
| Multi-file $ref resolution (resolving refs to external URIs or local files) | Single-document input is the stated constraint; cross-file resolution requires HTTP fetch or file picker, adding significant complexity and a server or CORS concerns | Treat `$ref` values pointing outside `#/definitions/` as unresolvable; display them as "external ref" labels |
| Automatic layout animation | Animating expand/collapse is tempting but complex in SVG Elm; adds performance risk on large schemas | Use instant show/hide (visibility: hidden or conditional rendering); keep layout fast |
| Search / filter within diagram | Useful but a second-order feature — users need to be able to see the diagram first | Defer to post-v1 |
| Schema version auto-detection (draft-04, draft-06, draft-07, 2019-09, 2020-12) | Decoder is built for draft-07; auto-detecting and switching decoders multiplies complexity | Declare draft-07 support clearly in the UI; decode with the existing decoder and let it degrade gracefully |
| Rendering as HTML/CSS instead of SVG | The SVG renderer is already built and the coordinate-threading pattern is established | Stay SVG; the existing investment is sound |
| Dark/light mode toggle | Not core to diagram usability; current dark color scheme (blue `#3972CE` bg, light `#e6e6e6` text) is workable | Keep the current color scheme for v1 |

---

## Feature Dependencies

```
User input (paste textarea)
  → requires Browser.element (replaces Browser.sandbox)
  → requires Model to hold both raw text and decoded schema
  → required by ALL other features (without user input, the app is not usable)

$ref inline expansion
  → requires circular reference guard (Set String of in-progress refs)
  → required for real-world schema correctness

Connector lines
  → requires knowing child positions after layout (already tracked by Dimensions return)
  → enhances visual clarity of parent-child relationships

Collapse/expand nodes
  → requires Browser.element (has Cmd/Sub support, not needed here, but sandbox is too limited for state)
  → requires stable node IDs (path-based: "root.properties.fruits.items")
  → requires Model to hold Set NodeId of collapsed nodes
  → required for usability on large schemas
  → enables "Expand all / Collapse all"

Description tooltip
  → requires nothing new architecturally (SVG <title> is passive)
  → depends on nothing

Dynamic SVG viewport sizing
  → requires using Dimensions returned by viewSchema to set viewBox
  → prerequisite for connector lines and collapse/expand to work at all sizes

Required/optional visual distinction
  → requires only changing viewProperty to inspect the ObjectProperty constructor
  → depends on nothing new

Format annotation on string nodes
  → requires only changing viewSchema's String branch
  → depends on nothing new
```

---

## MVP Recommendation

Build in this order — each item unblocks the next:

1. **User schema input** — Upgrade to `Browser.element`, add `textarea`, wire `decodeString decoder` to input. Removes the hardcoded schema. Without this, nothing else matters.

2. **Dynamic SVG viewport** — Use the `Dimensions` already returned by `viewSchema` to compute `viewBox` dynamically. Fixes clipping on any real schema. Low risk, high payoff.

3. **Required/optional visual distinction** — One-line change in `viewProperty`: bold the name or append "*" for `Required`. Costs almost nothing.

4. **Format annotation and description tooltip** — Show `StringFormat` as a tag inside the string node. Add SVG `<title>` for descriptions. Both are cosmetic additions to existing render branches.

5. **$ref inline expansion** — Change the `Ref` branch in `viewSchema` to recurse into the resolved schema with a `Set String` guard for circular refs. This is the biggest correctness gap. Without it, any schema using definitions renders incompletely.

6. **Connector lines** — Thread connector-drawing into `viewProperties` and `viewItems` using the already-returned coordinates. The coordinate system already supports this; it's an SVG drawing addition.

7. **Collapse/expand nodes** — Add `Set NodeId` to `Model`, assign path-based IDs to nodes, add click handlers. This makes the tool usable for large real-world schemas (OpenAPI, etc.). Highest interaction complexity but highest value for exploration.

Defer:
- **Cardinality annotations**: Nice-to-have, data is decoded, but adds visual noise before the diagram is otherwise clean
- **Pan and zoom**: Needs JS interop or complex SVG transform handling — too risky for first milestone
- **Enum display**: Useful but can overflow nodes; needs design thought about layout

---

## Sources

- Training knowledge of Altova XMLSpy schema diagram view (XSD content model view), Liquid XML Studio Schema Browser, Oxygen XML Editor JSON/XML schema diagram — MEDIUM confidence (established tools, well-documented behavior, but not live-verified)
- Codebase analysis: `/home/eelco/Source/elm/jsonschema-viewer/src/Render/Svg.elm`, `src/Json/Schema.elm`, `src/Main.elm` — HIGH confidence (direct source reading)
- PROJECT.md requirements — HIGH confidence
