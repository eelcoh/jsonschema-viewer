# Phase 4: Visual Polish - Research

**Researched:** 2026-04-05
**Domain:** Elm 0.19.1 SVG — cubic bezier connector lines and conditional strokeDasharray on pill nodes
**Confidence:** HIGH

## Summary

Phase 4 makes two targeted changes to `src/Render/Svg.elm`. First, it adds cubic bezier connector paths between every parent node and each of its visible children (VIS-01). Second, it applies a dashed border (`strokeDasharray`) to `$ref` pill nodes and the cycle indicator pill (VIS-02).

The full visual contract is locked in `04-UI-SPEC.md` (colors, stroke values, bezier control-point formula, dasharray pattern). The coordinate-threading pattern already threads exact pixel positions through every view function, so both additions are pure SVG emits from data already available at the call sites. No new Elm packages are needed; all required SVG attributes (`strokeDasharray`, `<path>` with cubic bezier `C` command) are available in `elm/svg 1.0.1`.

The only non-trivial design question is the connector line geometry. The UI-SPEC prescribes cubic bezier with `horizontalOffset = (endX - startX) * 0.5`. This is the standard "S-curve" used in tree diagrams and is well-supported in SVG.

**Primary recommendation:** Implement both changes in a single plan with two tasks: (1) connector paths inside `viewProperties` and `viewItems`, (2) conditional dashed border inside `iconRect` and the cycle pill branch of `viewSchema`.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Curved bezier paths from parent to each child node. Smooth curves fan out from the parent's right edge to each child's left edge.
- **D-02:** Lines appear when a node is expanded and disappear when collapsed (integrates with Phase 3 expand/collapse state).
- **D-03:** Claude's discretion — pick a color and thickness that works with the existing dark theme (`darkClr` background, `lightClr` text/borders). Should complement without competing with node pills.
- **D-04:** Lines exit from the right-center of the parent pill and enter at the left-center of each child pill. Standard left-to-right tree diagram convention.
- **D-05:** $ref nodes use a dashed border (`strokeDasharray`) instead of the solid border used by inline schema nodes. Same pill shape, same background color, same `*` icon — only the border style changes.
- **D-06:** The existing ↺ cycle indicator pill (Phase 2) also gets the dashed border style, since it represents a circular $ref.

### Claude's Discretion
- Exact bezier curve control points for the connector paths
- Connector line color and thickness (D-03)
- `strokeDasharray` pattern for the dashed border (e.g., "4 2", "6 3")
- Whether connector lines should have rounded endpoints (`stroke-linecap: round`)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VIS-01 | Connector lines link parent nodes to their child properties | Cubic bezier `<path>` emitted inside `viewProperties` / `viewItems` using coordinates already returned by child render calls. `viewProperties` iterates children accumulating y-offsets; parent right-edge and child left-edge are both available at that site. |
| VIS-02 | `$ref` nodes have a distinct visual style (dashed border or link icon) distinguishing them from inline schemas | `iconRect` receives the `Icon` type as first argument. When `icon` is `IRef _`, add `SvgA.strokeDasharray "5 3"` to the `<rect>` attribute list. Cycle pill is rendered directly in the `Schema.Ref` branch of `viewSchema` — same attribute added there. |
</phase_requirements>

---

## Standard Stack

Phase 4 requires no new packages. All needed SVG capabilities are in existing dependencies.

### Core (existing)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `elm/svg` | 1.0.1 | SVG element and attribute primitives | Already in use; `Svg.path`, `SvgA.d`, `SvgA.strokeDasharray` are all in this package |
| `elm/html` | 1.0.0 | HTML wrapper for SVG output | Already in use |

### SVG Attributes Used by Phase 4
| Attribute | Module | Note |
|-----------|--------|------|
| `SvgA.d` | `Svg.Attributes` | Path data string for `<path>` — used to express cubic bezier |
| `SvgA.strokeDasharray` | `Svg.Attributes` | Dashed border pattern on `<rect>` |
| `SvgA.strokeLinecap` | `Svg.Attributes` | Already used in `separatorGraph`; reuse pattern for connector paths |
| `SvgA.fill` | `Svg.Attributes` | Set to "none" on connector `<path>` |

**Installation:** No new packages. All attributes are in `elm/svg 1.0.1` which is already a direct dependency.

---

## Architecture Patterns

### Existing: Coordinate Threading
Every view function returns `(Svg msg, Dimensions)` where `Dimensions = (Float, Float)` representing `(rightEdge, bottomEdge)` of the rendered element. This is the mechanism that makes connector lines possible without a separate layout pass.

Key derived values available at call sites:
- Parent node right-center: `(parentRightEdge, parentY + pillHeight/2)` where `pillHeight = 28`
- Child node left-center: `(childX, childY + pillHeight/2)` where `childX` is the x passed into the child render call

### Existing: `viewProperties` Iteration Pattern
```elm
-- Simplified structure (Render/Svg.elm lines 65-97)
viewProperties visited defs collapsedNodes toggleMsg path coords props =
    -- iterates over props
    -- for each: calls viewProperty which returns (Svg msg, Dimensions)
    -- accumulates y offsets: next child at (x, prevBottomEdge + ySpace)
    -- collects list of Svg msg
```

Connector lines are generated alongside each child render. The parent's right edge (and y midpoint) is known at the call site; the child's left edge equals the x passed into it; the child's y midpoint is `childY + pillHeight/2`.

### Pattern: `connectorPath` Pure Function (New)
```elm
-- New helper to introduce
connectorPath : Coordinates -> Coordinates -> Svg msg
connectorPath (startX, startY) (endX, endY) =
    let
        hOffset = (endX - startX) * 0.5
        cp1x = startX + hOffset
        cp2x = endX - hOffset
        d =
            "M " ++ String.fromFloat startX ++ " " ++ String.fromFloat startY
            ++ " C " ++ String.fromFloat cp1x ++ " " ++ String.fromFloat startY
            ++ " " ++ String.fromFloat cp2x ++ " " ++ String.fromFloat endY
            ++ " " ++ String.fromFloat endX ++ " " ++ String.fromFloat endY
    in
    Svg.path
        [ SvgA.d d
        , SvgA.stroke "#8baed6"
        , SvgA.strokeWidth "1.5"
        , SvgA.strokeLinecap "round"
        , SvgA.fill "none"
        ]
        []
```

Source: UI-SPEC SVG Visual Contracts section; CONTEXT.md D-01, D-04.

### Pattern: Conditional `strokeDasharray` in `iconRect`
The `iconRect` function builds the `<rect>` element with a fixed attribute list. The change introduces a conditional: when `icon` is `IRef _`, append `SvgA.strokeDasharray "5 3"` to the rect's attribute list.

```elm
-- Current rect attrs (Render/Svg.elm lines 544-555)
rct =
    Svg.rect
        [ SvgA.x ..., SvgA.y ..., SvgA.width ..., SvgA.height "28"
        , bg, border, SvgA.strokeWidth "0.2", SvgA.rx "2", SvgA.ry "2"
        ]
        []

-- Modified: add dasharray when IRef
dashAttrs =
    case icon of
        IRef _ -> [ SvgA.strokeDasharray "5 3" ]
        _      -> []

rct =
    Svg.rect
        ([ SvgA.x ..., ... , SvgA.rx "2", SvgA.ry "2" ] ++ dashAttrs)
        []
```

Source: UI-SPEC Component Inventory; CONTEXT.md D-05.

### Pattern: Cycle Pill Gets Same Dashed Border
The cycle pill is rendered directly in the `Schema.Ref` branch (line 261 in current `viewSchema`) via a call to `iconRect (IRef "*") ...`. Since the `IRef _` check in `iconRect` handles this branch automatically, the cycle pill receives the dashed border at no extra cost. D-06 is satisfied by the same change that satisfies D-05.

### Connector Lines Must Only Appear for Visible Children
D-02 is satisfied structurally: `viewProperties` and `viewItems` are only called when the node is NOT in `collapsedNodes`. The collapsed branch returns early before calling `viewProperties`. Connectors emitted inside `viewProperties`/`viewItems` are therefore naturally invisible when collapsed.

### Recommended File Structure (no changes)
```
src/
├── Render/
│   └── Svg.elm   -- all changes land here
├── Json/
│   └── Schema/
│       ├── Model.elm
│       └── Decode.elm
└── Main.elm
```

### Anti-Patterns to Avoid
- **Storing parent coordinates separately:** The start point of each connector is derivable from the `Dimensions` returned by the parent `iconRect` call. Do not introduce a separate state variable.
- **Emitting connectors outside `viewProperties`/`viewItems`:** The child's y coordinate is only known during iteration. Attempting to batch connector emission after iteration requires re-deriving positions.
- **Changing `viewProperties` return type:** Adding connectors as additional `Svg msg` elements to the existing returned list is sufficient; the return type does not need to change.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Path string construction | Custom SVG DSL | Direct string interpolation with `String.fromFloat` — SVG path mini-language is simple enough here |
| Color manipulation | Custom blend logic | Use literal hex `"#8baed6"` per UI-SPEC; `avh4/elm-color` already in deps if needed |
| Layout engine | Separate layout pass | Coordinate threading already provides all positions |

**Key insight:** The existing coordinate-threading pattern is the layout engine. Connectors are a rendering step, not a layout step.

---

## Common Pitfalls

### Pitfall 1: Off-by-pillHeight/2 on Connector Y
**What goes wrong:** Connector line connects to the top-left corner of the pill instead of its left-center.
**Why it happens:** Forgetting that `y` in the coordinate system is the top of the pill; the center is `y + pillHeight/2` = `y + 14`.
**How to avoid:** Always compute `childY + 14` for the child end point and `parentY + 14` for the parent start point (where `pillHeight = 28`).
**Warning signs:** Connector lines enter/exit pill corners instead of mid-left/mid-right.

### Pitfall 2: Connector Start X Using Pill-Left Instead of Pill-Right
**What goes wrong:** Connector starts from the left edge of the parent pill rather than its right edge.
**Why it happens:** The coordinates passed into `viewProperties` are the parent's right-edge x value (the `w` from `iconRect`'s returned `Dimensions`). This is already the start x. No further addition needed.
**How to avoid:** Use the `w` from `iconRect`'s returned `Dimensions` directly as `startX`. Do not add `rectWidth` again.
**Warning signs:** Bezier curves overlap the parent node body.

### Pitfall 3: Connector Lines Render for Collapsed Nodes
**What goes wrong:** Connectors appear even when a node is collapsed.
**Why it happens:** If connector emission is placed outside the collapsed-check branch.
**How to avoid:** Confirm connectors are only emitted inside the `else` branch (expanded case) where `viewProperties`/`viewItems` are called. The structure in `viewSchema` already gates on `Set.member path collapsedNodes`.
**Warning signs:** Orphaned lines extend from collapsed pills to empty space.

### Pitfall 4: `strokeDasharray` Breaking Non-$ref Nodes
**What goes wrong:** Dashed borders appear on object, string, or other inline schema nodes.
**Why it happens:** Applying `strokeDasharray` unconditionally in `iconRect`.
**How to avoid:** Gate on `case icon of IRef _ -> [...] _ -> []` pattern.
**Warning signs:** All node borders become dashed.

### Pitfall 5: Bezier Control Points When Start and End Have Same X
**What goes wrong:** When a child happens to align vertically with the parent (same x), `horizontalOffset = 0` and the bezier degenerates to a straight vertical line.
**Why it happens:** The horizontal tree layout means children always have larger x than parents (`w + 10`), so in practice `endX > startX` always holds. This pitfall is theoretical but worth knowing.
**How to avoid:** No special handling needed given the layout invariant — children are always placed to the right of their parent.

---

## Code Examples

### Connector Path (complete function)
```elm
-- Source: UI-SPEC SVG Visual Contracts (connector lines section)
connectorPath : Coordinates -> Coordinates -> Svg msg
connectorPath ( startX, startY ) ( endX, endY ) =
    let
        hOffset =
            (endX - startX) * 0.5

        d =
            "M "
                ++ String.fromFloat startX
                ++ " "
                ++ String.fromFloat startY
                ++ " C "
                ++ String.fromFloat (startX + hOffset)
                ++ " "
                ++ String.fromFloat startY
                ++ " "
                ++ String.fromFloat (endX - hOffset)
                ++ " "
                ++ String.fromFloat endY
                ++ " "
                ++ String.fromFloat endX
                ++ " "
                ++ String.fromFloat endY
    in
    Svg.path
        [ SvgA.d d
        , SvgA.stroke "#8baed6"
        , SvgA.strokeWidth "1.5"
        , SvgA.strokeLinecap "round"
        , SvgA.fill "none"
        ]
        []
```

### Connector Emission Site in `viewProperties`
```elm
-- Inside the inner viewProps recursion, after calling viewProperty:
let
    ( g_, ( w1, h1 ) ) =
        viewProperty visited defs collapsedNodes toggleMsg path coords_ element

    -- Parent right-center: the x passed into viewProperties is parentW
    -- Child left-center:   childX = x (same x as all siblings), childY from coords_
    ( childX, childY ) = coords_
    ( parentX, parentY ) = coords  -- the (w+10, y) passed in from viewSchema
    -- Note: parentX is where children START; the parent's right edge is parentX - 10
    -- connector start = parent pill right edge = parentX - 10, parentY + 14
    -- connector end   = child pill left edge   = childX, childY + 14
    connector =
        connectorPath
            ( parentX - 10, parentY + 14 )
            ( childX, childY + 14 )
```

Note: The exact parentX arithmetic depends on how `viewProperties` is called. In `viewSchema`, the call is `viewProperties ... (w + 10, y) properties` where `w` is `iconRect`'s right edge. So `parentX - 10 = w` = parent pill right edge. Verify this in implementation.

### Dashed Border in `iconRect`
```elm
-- Source: UI-SPEC Component Inventory
dashAttrs : List (Svg.Attribute msg)
dashAttrs =
    case icon of
        IRef _ ->
            [ SvgA.strokeDasharray "5 3" ]

        _ ->
            []

rct =
    Svg.rect
        ([ SvgA.x (String.fromFloat x)
         , SvgA.y (String.fromFloat y)
         , SvgA.width wRect
         , SvgA.height "28"
         , bg
         , border
         , SvgA.strokeWidth "0.2"
         , SvgA.rx "2"
         , SvgA.ry "2"
         ]
            ++ dashAttrs
        )
        []
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No connector lines | Cubic bezier `<path>` connectors | Phase 4 | Tree structure is visually explicit |
| Uniform solid borders | Dashed border for `IRef _` nodes | Phase 4 | `$ref` / cycle nodes are visually distinguishable |

**No deprecated patterns introduced.** All new SVG attributes (`strokeDasharray`, `<path>` with `d`) are standard SVG 1.1 and fully supported in `elm/svg 1.0.1`.

---

## Open Questions

1. **Exact parent x-coordinate for connector start**
   - What we know: `viewProperties` is called with `(w + 10, y)` where `w` is the parent pill right edge. The connector should start at `(w, parentY + 14)`.
   - What's unclear: Whether the `(w + 10, y)` passed to children means the connector start is `childStartX - 10` or requires threading `w` separately into `viewProperties`.
   - Recommendation: Thread the parent's right-edge `w` as an explicit parameter to `viewProperties` (or derive it as `childStartX - 10` which equals `w`). Either is correct — verify with a quick visual check during implementation.

2. **`viewMulti` connector lines**
   - What we know: `viewMulti` (oneOf/anyOf/allOf) also calls `viewItems` to render sub-schemas. The UI-SPEC and CONTEXT.md do not explicitly address connectors for multi-schema nodes.
   - What's unclear: Whether connectors should also appear from `|1|`, `|o|`, `(&)` pills to their sub-schemas.
   - Recommendation: Apply the same pattern as `viewProperties` — if `viewItems` emits connectors, `viewMulti`'s children get them too. This is consistent with D-01 ("each child node"). If the user wants to exclude multi-schema connectors, it requires explicit scoping. Default to including them.

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified — all changes are pure Elm code within existing build pipeline)

---

## Validation Architecture

`workflow.nyquist_validation` is not set in `.planning/config.json` (key absent) — treat as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | elm-explorations/test 2.0.0 |
| Config file | none (elm-test convention-based) |
| Quick run command | `elm-test` |
| Full suite command | `elm-test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VIS-01 | `connectorPath` produces correct SVG `d` attribute string | unit | `elm-test --watch` | ❌ Wave 0 |
| VIS-01 | Connector start/end coordinates computed correctly from pill geometry | unit | `elm-test` | ❌ Wave 0 |
| VIS-02 | `iconRect IRef` includes `strokeDasharray "5 3"` in rect attrs | unit | `elm-test` | ❌ Wave 0 |
| VIS-02 | `iconRect IObject` does NOT include `strokeDasharray` | unit | `elm-test` | ❌ Wave 0 |

Note: The SVG output of `iconRect` and `connectorPath` cannot be directly inspected via elm-test (no DOM access), but the pure string/coordinate helper functions (`connectorPath`, coordinate arithmetic) are fully unit-testable. Visual integration testing requires manual browser inspection.

### Sampling Rate
- **Per task commit:** `elm make src/Main.elm --output=/dev/null` (compile check)
- **Per wave merge:** `elm-test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/Tests.elm` — add `connectorPath` coordinate tests (extend existing file)
- [ ] Manual: open `public/index.html` with the Address schema example to visually confirm connector lines and dashed borders

*(Existing `tests/Tests.elm` exists with stub tests. New test cases are additions, not a new file.)*

---

## Sources

### Primary (HIGH confidence)
- `src/Render/Svg.elm` — direct code inspection; all coordinate values, function signatures, and attribute patterns verified from source
- `04-UI-SPEC.md` — visual contract approved for this phase; color values, strokeDasharray pattern, bezier formula
- `04-CONTEXT.md` — locked decisions D-01 through D-06
- `elm.json` — dependency versions verified

### Secondary (MEDIUM confidence)
- SVG 1.1 specification: `<path>` cubic bezier `C` command and `stroke-dasharray` are SVG 1.1 standard features, universally supported in browser SVG renderers
- `elm/svg 1.0.1` package: `Svg.path`, `SvgA.d`, `SvgA.strokeDasharray` are in the package (confirmed by existing use of sibling attributes in the codebase)

### Tertiary (LOW confidence)
None.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all attributes verified in existing codebase
- Architecture: HIGH — coordinate threading pattern confirmed by direct code inspection; connector insertion points are unambiguous
- Pitfalls: HIGH — derived from direct code analysis of the renderer
- Connector coordinate arithmetic: MEDIUM — the exact `parentX - 10` derivation needs a quick verification during implementation (Open Question 1)

**Research date:** 2026-04-05
**Valid until:** Stable — Elm 0.19.1 and elm/svg 1.0.1 are frozen packages; no expiry concern
