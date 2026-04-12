# Phase 7: Node Design and Information Density - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 07-node-design-and-information-density
**Areas discussed:** Required property marker, Metadata layout strategy, Format badge design, Constraint & enum display

---

## Required Property Marker

| Option | Description | Selected |
|--------|-------------|----------|
| Asterisk suffix | Append red/orange asterisk (*) after property name | |
| Colored border accent | Required nodes get amber border, optional keep default #a0c4e8 | ✓ |
| Dot indicator | Small filled dot before property name for required | |

**User's choice:** Colored border accent
**Notes:** None

### Follow-up: Bold + Border

| Option | Description | Selected |
|--------|-------------|----------|
| Keep bold + amber border | Double signal — border color + bold font weight | ✓ |
| Amber border only | Single signal — uniform font weight, rely on color alone | |

**User's choice:** Keep bold + amber border (double signal)
**Notes:** None

---

## Metadata Layout Strategy

User clarified prior decisions before options were presented:
- Keep information at a minimum on nodes
- Make email a type instead of a format
- Have a mechanism to expand or overlay for extra information

These prior decisions were not captured in any CONTEXT.md file but informed all subsequent discussion.

### Interaction Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Click to expand node | Click leaf node to show metadata below, extends Phase 3 pattern | |
| Hover overlay | Floating info panel on hover, no layout shift, disappears on mouse-out | ✓ |
| You decide | Claude picks based on Elm SVG feasibility | |

**User's choice:** Hover overlay
**Notes:** Custom SVG overlay rendered by Elm, not browser-native tooltips

### Overlay Scope

| Option | Description | Selected |
|--------|-------------|----------|
| All nodes with metadata | Any node with description/constraints/enum gets overlay | ✓ |
| Leaf nodes only | Only primitive type nodes show overlays | |

**User's choice:** All nodes with metadata
**Notes:** None

---

## Format Badge Design

User clarified: well-known formats should be icons replacing 'S', not badges or suffixes.

### Custom Formats

| Option | Description | Selected |
|--------|-------------|----------|
| Keep S icon | Custom formats show as regular 'S' nodes, format in hover overlay | |
| Show format name as text | Replace 'S' with the custom format string in icon position | ✓ |

**User's choice:** Show format name as text
**Notes:** All formats (known and custom) replace the S icon

---

## Constraint & Enum Display

### Enum Display

User suggested: use Enum as type (same pattern as format-as-type).

| Option | Description | Selected |
|--------|-------------|----------|
| Enum icon replaces type | Generic enum icon in type position, base type in overlay | ✓ |
| Type + enum indicator | Keep base type icon, add small indicator for enum | |

**User's choice:** Enum replaces type
**Notes:** Values shown in hover overlay

### Constraint Hint on Pill

User confirmed: constraints live purely in hover overlay, no pill-level hint.

### Description Display

| Option | Description | Selected |
|--------|-------------|----------|
| Full description text | Show complete description string in overlay | ✓ |
| Truncated with ellipsis | First ~80 chars with '...' | |
| You decide | Claude picks | |

**User's choice:** Full description text
**Notes:** None

---

## Claude's Discretion

- Exact amber hex for required border
- Icon designs for well-known string formats
- Hover overlay positioning, sizing, styling
- NodeLayout refactoring approach
- Hover state management in Model

## Deferred Ideas

None — discussion stayed within phase scope
