# Feature Landscape: v1.1 Professional Visuals

**Domain:** JSON Schema SVG Visualization (Elm 0.19.1)
**Researched:** 2026-04-09

## Table Stakes

Features users expect from a professional schema visualization tool. Missing = product feels amateurish or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Type-based color coding | Every professional schema tool (Redoc, Swagger UI, Stoplight, JSON Crack) uses color to distinguish types. Current monochrome blue pills look prototypal. | Medium | Must be colorblind-safe. Okabe-Ito palette adapted for dark background. |
| Required vs optional visual distinction | Swagger UI, Redoc, Stoplight all clearly mark required fields. Current bold/normal weight is too subtle at small sizes. | Low | Add asterisk marker or badge. Bold weight alone is insufficient. |
| Description display | Schemas carry `description` fields. Redoc and Stoplight show them inline. Hiding them wastes the most useful annotation in any schema. | Medium | Already decoded into model (`BaseSchema` has `description : Maybe String`). Render as secondary text below node name. |
| Constraint display | Professional tools show min/max, pattern, format inline with the type. Redoc shows "[ 1 .. 255 ] characters" next to string types. | Medium | Model already has `minLength`, `maxLength`, `minimum`, `maximum`, `pattern`, `format`. Render as compact tertiary annotation. |
| Enum value display | When a schema has `enum`, users need to see allowed values. Redoc shows them as inline chips/badges. | Low-Med | Model has `enum : Maybe (List a)` on string, integer, number, boolean schemas. Show as comma-separated or chip row. |
| `$defs` support (JSON Schema 2020-12) | JSON Schema 2020-12 moved `definitions` to `$defs`. Schemas from modern tooling (TypeBox, Zod, Ajv) use `$defs`. Current decoder silently produces empty definitions for these schemas. | Low | Current `definitionsDecoder` only reads `"definitions"`. Add a `oneOf [ field "definitions" ..., field "$defs" ... ]` fallback. Already decoded; just a decoder fix. |
| Handle type + combinator schemas | Schemas like `{ "type": "object", "oneOf": [...] }` are valid. The current decoder's `withType` guard causes the object branch to match first and discard the `oneOf`. These render as plain objects with no combinator children. | Medium | Requires rethinking decoder `oneOf` priority — either separate combinator detection before type-gated branches, or try combinators last when type is present. Affects schema model structure decisions. |

## Differentiators

Features that set this tool apart from text-based schema viewers.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Blueprint/technical aesthetic | Most schema tools are text-document oriented (Redoc, Swagger). A dark navy SVG diagram with blueprint styling is visually distinct and memorable. | Medium | Dark navy background (#1a2332 range), thin grid lines, monospace type for values, sans-serif for labels. |
| Type-colored connector lines | Connector lines that inherit parent node type color. No other schema tool does this. Current uniform #8baed6 lines are functional but miss the opportunity. | Low | Pass the parent type color into `connectorPath`. Requires type-color palette first. |
| Format badges | Show string format (email, uri, date-time, ipv4, etc.) as a distinct tag on string nodes. Immediately communicates semantic meaning beyond "string". | Low | `StringFormat` type already decoded. Render as small tag next to or below type icon. |
| Collapse indicator count | When a node is collapsed, show child count badge (e.g., "User {5}" meaning 5 properties). Provides information scent without expanding. | Low | Count `List.length properties` and render in the pill. |
| Expanded node cards | Instead of fixed-height pills, show multi-line cards for nodes with rich metadata. Progressive disclosure: collapsed = pill, expanded = card with description + constraints. | High | Requires rethinking coordinate-threading to handle variable-height nodes. Most impactful visual upgrade, highest risk. |

## Anti-Features

Features to explicitly NOT build in v1.1.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Tooltip/hover popups for constraints | SVG tooltips are janky, require foreign objects or complex overlay management in Elm. Hover state management adds significant complexity. | Show constraints inline as tertiary text in the node. Always visible beats hover-to-discover. |
| Dark mode toggle | Adding theme switching doubles the visual design work and testing surface. | Commit to the blueprint dark theme as the single aesthetic. |
| Drag-to-rearrange nodes | Requires a physics engine or constraint solver. Massively complex for marginal value in a read-only viewer. | Keep the deterministic left-to-right tree layout. |
| Animated transitions | SVG animations in Elm require manual animation frames or ports. High complexity, low value for a technical tool. | Instant expand/collapse is fine. Technical users prefer speed over animation. |
| Multi-schema `$defs` cross-referencing | Resolving `$ref` across separately uploaded schemas requires a ref registry and multi-input UI. Out of scope for a single-document viewer. | Resolve `$defs` within the single loaded document only. |

## Feature Dependencies

```
$defs Decoder Fix         -->  Accurate rendering for 2020-12 schemas
Type+Combinator Fix       -->  Accurate rendering for modern toolchain schemas
                              (TypeBox, Zod output uses type+oneOf frequently)

Blueprint Aesthetic       -->  ALL visual features (background determines contrast requirements)
Type Color Coding         -->  Type-Colored Connectors (connectors need the color values)
Type Color Coding         -->  Blueprint Aesthetic (colors must work on dark background)
Description Display       -->  Expanded Node Cards (cards need multi-line layout)
Constraint Display        -->  Expanded Node Cards (constraints need vertical space)
Constraint Display        -->  Depends on: variable-height node layout (PITFALL-01)
Expanded Node Cards       -->  NodeLayout record refactor (see PITFALLS.md Pitfall 1)
```

**Critical paths:**
1. Decoder fixes are independent — they can be done first or last, but should be done before UAT so test schemas render correctly.
2. Blueprint Aesthetic must come before color-dependent features.
3. Variable-height nodes (Expanded Node Cards, Description Display with multi-line wrapping) require the NodeLayout refactor first — do not start these without the refactor.

## MVP Recommendation

### Phase A: Decoder Fixes (independent, unblocks test coverage)
1. `$defs` support — tiny change, unblocks modern schemas
2. Type + combinator handling — requires decoder restructure, medium complexity

### Phase B: Foundation (Blueprint + Color)
3. Blueprint dark background — sets visual context for everything
4. Type-based color coding — highest visual impact per effort
5. Type-colored connector lines — low effort once colors exist
6. Collapse indicator count — low effort, high information value

### Phase C: Information Density
7. Description display — high value, medium complexity
8. Constraint display — high value, needs compact notation
9. Format badges — low effort, good semantic value
10. Enum value display — medium complexity

### Phase D: Node Evolution (if scope allows)
11. Expanded node cards — high complexity, requires NodeLayout refactor first; may be v1.2

**Defer:** Expanded node cards to v1.2 if the NodeLayout refactor surfaces unexpected complexity in the coordinate-threading system.

---

## Detailed Research Findings

### Type-Based Color Coding

**Industry conventions:**

No universal standard exists, but strong conventions emerge from IDE syntax highlighting, API documentation tools, and data visualization practice:

| Type | Conventional Color Family | Rationale |
|------|--------------------------|-----------|
| Object | Blue / Teal | Structural/container. Blue conveys depth. Used by VS Code for class/type names. |
| Array | Purple / Violet | Container type, distinct from object. Secondary to blue in visual hierarchy. |
| String | Green | Near-universal convention from syntax highlighting (VS Code, Sublime, IntelliJ). |
| Integer/Number | Orange / Amber | Warm color for numeric literals. |
| Boolean | Pink / Magenta | Small, binary type. Magenta is eye-catching for always-true/false. |
| Null | Gray | Absence of value. Muted color is semantically appropriate. |
| Ref ($ref) | Cyan / Light Blue | References are pointers. Cyan suggests indirection. Dashed border already in place. |
| OneOf/AnyOf/AllOf | Yellow / Gold | Combinators are schema composition points — gold draws attention. |

**Recommended palette (colorblind-safe, dark-background optimized, Okabe-Ito based):**

| Type | Hex | Base | Notes |
|------|-----|------|-------|
| Object | `#56B4E9` | Okabe-Ito Sky Blue | Excellent on dark backgrounds |
| Array | `#CC79A7` | Okabe-Ito Reddish Purple | Distinct from blue |
| String | `#009E73` | Okabe-Ito Bluish Green | May need lightening to `#00C896` for contrast |
| Integer | `#E69F00` | Okabe-Ito Orange | Warm numeric convention |
| Number | `#D4A017` | Adjusted Gold | Slightly shifted from integer orange |
| Boolean | `#D55E00` | Okabe-Ito Vermilion | Distinct from orange |
| Null | `#7A8B99` | Custom Gray | Neutral, absent value |
| Ref | `#78D4F0` | Lightened Sky Blue | Lighter object blue + dashed border |
| Combinators | `#F0E442` | Okabe-Ito Yellow | Attention-drawing |

All colors need contrast verification against ~`#1a2332` background (WCAG AA: 4.5:1 for text, 3:1 for graphical elements).

**Confidence:** HIGH for the approach. MEDIUM for specific hex values (will need visual testing).

### Blueprint/Technical Visual Style

**What "blueprint" means visually:**
1. **Background:** Deep navy `#1a2332` to `#1e293b` — not pure black. Blueprint paper is dark blue.
2. **Grid:** Subtle grid lines (`#2a3a4d`, ~0.5px) at regular intervals — creates technical drawing feel. Optional but effective.
3. **Borders:** Thin light borders (`#4a5d73`, 0.5-1px). Not heavy outlines.
4. **Text:** Light/white primary (`#e2e8f0`), muted secondary (`#94a3b8`), monospace for values.
5. **Nodes:** Slightly lighter card backgrounds (`#243447`) on top of grid background.
6. **Connectors:** Type-colored at ~60% opacity, not bright white.

**Typography hierarchy for SVG nodes:**

| Level | Use | Font | Size | Weight | Color |
|-------|-----|------|------|--------|-------|
| Primary | Property name | Monospace | 12px | 700 required / 400 optional | `#e2e8f0` (bright) |
| Secondary | Description | Sans-serif or Monospace | 10px | 400 | `#94a3b8` (muted) |
| Tertiary | Constraints, format | Monospace | 9px | 400 | `#64748b` (dim) or type color at 60% |
| Icon | Type indicator | Monospace | 12px | 700 | Type color from palette |
| Badge | Format, enum count | Monospace | 9px | 400 | Type color background, dark text |

**Confidence:** HIGH. Blueprint dark aesthetic is well-established in draw.io dark mode, Mermaid dark theme, and CAD tools.

### Constraint Display Patterns

**How professional tools display constraints:**

Redoc renders inline with type annotation in humanized format:
- String: `string [ 1 .. 255 ] characters` or `string >= 1 characters`
- Number: `integer [ 0 .. 100 ]`
- Array: `array [ 1 .. 10 ] items`
- Pattern: `string /^[a-zA-Z]+$/`
- Format: `string <email>` or `string <date-time>`

**Compact notation for SVG nodes** (space-constrained):

| Constraint | Compact Format | Example |
|------------|---------------|---------|
| minLength + maxLength | `[min..max]` | `[1..255]` |
| minLength only | `[min..]` | `[1..]` |
| maxLength only | `[..max]` | `[..255]` |
| minimum + maximum | `[min..max]` | `[0..100]` |
| minimum only | `>=min` | `>=0` |
| maximum only | `<=max` | `<=100` |
| pattern | `/pattern/` | `/^[a-z]+$/` (truncate >20 chars) |
| format | `<format>` | `<email>` |
| enum | `{val1\|val2\|...}` | `{red\|green\|blue}` |
| minItems + maxItems | `[min..max] items` | `[1..10] items` |

**Confidence:** HIGH. This notation pattern is standard across Redoc, Swagger, and OpenAPI tooling.

### Decoder Fixes

#### `$defs` Support

JSON Schema 2020-12 replaced `definitions` with `$defs`. The current decoder:
```elm
definitionsDecoder = field "definitions" (...)
```
...silently returns `Dict.empty` for 2020-12 schemas. Fix: `oneOf [ field "definitions" ..., field "$defs" ... ]`.

**Why this matters:** TypeBox, Zod's `z.toJsonSchema()`, and Ajv all produce 2020-12 schemas with `$defs`. These are the schemas developers are most likely to paste into the viewer from real projects.

#### Combined Type + Combinator Schemas

Schemas like `{ "type": "object", "properties": {...}, "oneOf": [...] }` are valid JSON Schema draft-07 and 2020-12. The current decoder structure:
```elm
oneOf
    [ ... |> withType "object"   -- matches first, discards oneOf
    , ... |> required "oneOf" ...  -- never reached
    ]
```
The `withType "object"` branch succeeds and the `oneOf` field is silently ignored.

**Fix options:**
1. Detect combinators first regardless of `type` field presence — try `oneOf`/`anyOf`/`allOf` branches before type-gated branches
2. After matching object/array, also check for combinator fields and create a hybrid schema variant
3. Introduce a `Combined` schema variant that wraps `(Schema, CombinatorSchema)`

Option 1 is simplest but changes priority in ways that might cause other schemas to match incorrectly. Option 3 is most correct but requires model changes and new renderer support. **Recommended: Option 1 with careful testing** — move combinator branches before type-gated branches in the `oneOf` list, since schemas with explicit `type` + combinator are less common than pure combinators.

**Confidence:** MEDIUM for the fix strategy. The decoder is simple enough that the fix is low-risk, but the interaction with `withType` guards needs careful testing.

### Node Sizing and Layout

**Current state:** Fixed 28px pill height, monospace 12px font, 7.2px character width approximation.

**For v1.1 information density:**

| Node State | Height | Content |
|------------|--------|---------|
| Collapsed leaf (no children) | 28px | Icon + name (current) |
| Collapsed branch (has children) | 28px | Icon + name + child count badge |
| Expanded leaf with metadata | 44-56px | Icon + name (line 1), constraints/description (lines 2-3) |
| Expanded branch | 28px header + metadata | Header pill + description/constraints, then children |

**Critical implementation note:** The coordinate-threading pattern returns `(Svg msg, Dimensions)` where Dimensions encodes the bottom-right corner. Variable-height nodes require accurate height calculation BEFORE positioning children. The `pillHeight = 28` constant is implicitly used in `y + 14` (connector anchor), `y + 15` (text baseline), and `+ 10` vertical gap calculations. These must all become layout-derived. See PITFALLS.md for the NodeLayout refactor requirement.

**Layout spacing recommendations for v1.1:**

| Dimension | Current | Recommended | Rationale |
|-----------|---------|-------------|-----------|
| Horizontal gap (parent-child) | 10px | 20-24px | More breathing room for connector curves |
| Vertical gap (siblings) | 10px | 12-14px | More air when nodes gain metadata lines |
| Pill height | 28px | 28px base | Keep base, allow growth for metadata |
| Pill horizontal padding | 15px each side | 12px left / 16px right | Asymmetric for icon-on-left visual balance |

**Confidence:** HIGH for spacing rationale. MEDIUM for specific pixel values (will need visual iteration).

## Data Already in the Model

The schema model already decodes these fields that v1.1 should render:

| Field | Available On | Currently Rendered |
|-------|-------------|-------------------|
| `title` | All types | No |
| `description` | All types | No |
| `minimum` / `maximum` | Integer, Number | No |
| `minLength` / `maxLength` | String | No |
| `pattern` | String | No |
| `format` | String (as `StringFormat` union type) | No |
| `enum` | String, Integer, Number, Boolean | No |
| `minItems` / `maxItems` | Array | No |
| `minProperties` / `maxProperties` | Object | No |
| `examples` | All types | No |
| Required vs Optional | ObjectProperty | Yes (bold weight only) |

The rendering features (description, constraints, format badges, enum display) are purely visual upgrades — the data is already decoded. The decoder fixes (`$defs`, combined type+combinator) are the only changes to `Json.Schema.Decode`.

## Sources

- [Okabe-Ito palette](https://easystats.github.io/see/reference/scale_color_okabeito.html) — Colorblind-safe categorical palette (HIGH confidence)
- [Okabe-Ito hex codes](https://conceptviz.app/blog/okabe-ito-palette-hex-codes-complete-reference) — Complete hex reference (HIGH confidence)
- [Colorblind-safe palette guidance](https://davidmathlogic.com/colorblind/) — David Nichols interactive tool (HIGH confidence)
- [JSON Schema 2020-12 spec — $defs](https://json-schema.org/draft/2020-12/json-schema-core#section-8.2.4) — Official spec for $defs keyword (HIGH confidence)
- [TypeBox output format](https://github.com/sinclairzx81/typebox) — Produces 2020-12 schemas with $defs (MEDIUM confidence, GitHub)
- [Redoc theme configuration](https://github.com/Redocly/redoc/blob/main/src/theme.ts) — Schema rendering reference (HIGH confidence)
- [Swagger UI required field indicators](https://github.com/swagger-api/swagger-ui/issues/3255) — Required field convention (MEDIUM confidence)
- [IBM Design Language technical diagrams](https://www.ibm.com/design/language/infographics/technical-diagrams/design/) — Blueprint/technical aesthetic reference (HIGH confidence)
- [JSON Crack](https://jsoncrack.com) — JSON visualization reference (MEDIUM confidence)
- [Syntax highlighting conventions](https://en.wikipedia.org/wiki/Syntax_highlighting) — Color-to-type convention survey (HIGH confidence)
- Source inspection: `src/Json/Schema/Decode.elm` — Confirmed `$defs` gap and `withType` priority issue (HIGH confidence, direct code review)
