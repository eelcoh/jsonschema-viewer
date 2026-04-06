# Phase 3: Expand/Collapse - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-05
**Phase:** 03-expand-collapse
**Areas discussed:** Collapse state model, $ref inline expansion, Default expand depth, Click target & feedback

---

## Collapse State Model

### Node Identity

| Option | Description | Selected |
|--------|-------------|----------|
| Schema path key | Each node gets a path like "root.properties.address.properties.street". Natural, unique at each depth, survives re-parse. | ✓ |
| Positional index | Sequential index assigned during rendering. Simpler but fragile — re-ordering could invalidate indices. | |
| You decide | Let Claude choose based on implementation constraints. | |

**User's choice:** Schema path key
**Notes:** None

### State Persistence

| Option | Description | Selected |
|--------|-------------|----------|
| Reset on re-parse | Any schema change resets all nodes to default expand state. Simple, predictable, no stale path keys. | ✓ |
| Preserve where possible | Try to keep matching paths expanded/collapsed after re-parse. More complex. | |
| You decide | Let Claude choose based on implementation complexity. | |

**User's choice:** Reset on re-parse
**Notes:** None

### State Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Set of collapsed paths | Store a `Set String` of collapsed path keys. Default = empty (everything expanded). Toggling adds/removes. | ✓ |
| Set of expanded paths | Store expanded path keys. Default = computed from schema. More work to initialize. | |
| You decide | Let Claude choose based on default expand depth decision. | |

**User's choice:** Set of collapsed paths
**Notes:** None

---

## $ref Inline Expansion

### Click Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Expand inline | $ref expands in-place showing referenced definition's full structure. Uses existing Dict.get + visited-set. | ✓ |
| Navigate/scroll to definition | Clicking scrolls or highlights definition elsewhere in diagram. | |
| Both (toggle + link) | Click expands inline, plus subtle link icon to scroll to original. | |

**User's choice:** Expand inline
**Notes:** None

### Circular Reference Display

| Option | Description | Selected |
|--------|-------------|----------|
| Show cycle indicator pill | Display existing ↺ cycle indicator pill from Phase 2. Not clickable/expandable. | ✓ |
| Show truncated preview | Show 1-2 top-level properties plus '...' indicator, then stop. | |
| You decide | Let Claude choose simplest approach. | |

**User's choice:** Show cycle indicator pill
**Notes:** None

### Expanded $ref Styling

| Option | Description | Selected |
|--------|-------------|----------|
| Same as inline | Once expanded, looks identical to inline schema. Collapsed pill already has distinct style. | ✓ |
| Subtle visual wrapper | Light border or background tint around expanded ref content. | |
| You decide | Let Claude choose simplest and clearest. | |

**User's choice:** Same as inline
**Notes:** None

---

## Default Expand Depth

### Initial State

| Option | Description | Selected |
|--------|-------------|----------|
| Fully expanded | Keep current behavior — everything visible. Collapsed set starts empty. | ✓ |
| Expand to depth 2 | Root + first level visible, deeper collapsed. Requires computing initial set. | |
| $refs collapsed, rest expanded | Inline structure expanded, $ref nodes start collapsed. | |

**User's choice:** Fully expanded
**Notes:** None

---

## Click Target & Feedback

### Clickable Area

| Option | Description | Selected |
|--------|-------------|----------|
| Entire pill node | Clicking anywhere on pill toggles expand/collapse. Large target, consistent with XMLSpy-style tools. | ✓ |
| Dedicated +/- icon | Small icon next to container nodes. Only icon clickable. | |
| Both pill and icon | Icon for discoverability plus full pill clickable. | |

**User's choice:** Entire pill node
**Notes:** None

### Hover Feedback

| Option | Description | Selected |
|--------|-------------|----------|
| Cursor pointer only | Pointer cursor on hover for container nodes. Minimal, no extra SVG elements. | ✓ |
| Cursor + hover highlight | Pointer plus subtle background color change on hover. | |
| Arrow/chevron indicator | Small ▶/▼ arrow that rotates on collapse/expand. | |

**User's choice:** Cursor pointer only
**Notes:** None

### Leaf Node Interactivity

| Option | Description | Selected |
|--------|-------------|----------|
| Container nodes only | Only Object, Array, combinator, $ref are clickable. Leaf types have nothing to expand. | ✓ |
| All nodes clickable | Even leaf nodes respond to clicks (future details display). | |

**User's choice:** Container nodes only
**Notes:** None

---

## Claude's Discretion

- Path key separator and format details
- Threading path accumulator through view functions
- SVG click handler implementation approach
- Transition/animation on collapse (if any)

## Deferred Ideas

None — discussion stayed within phase scope
