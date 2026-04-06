# Phase 2: Correct Rendering - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-04
**Phase:** 02-correct-rendering
**Areas discussed:** $ref inline style, Required vs optional, Circular $ref guard, SVG viewport sizing

---

## $ref Inline Style

| Option | Description | Selected |
|--------|-------------|----------|
| Expand fully inline | Replace $ref node with full referenced schema — looks identical to inline definition | |
| Expand with ref badge | Expand referenced schema inline but keep $ref icon/label as parent node | |
| Ref node + expand on click | Show $ref as distinct labeled node; inline expansion deferred to Phase 3 | ✓ |

**User's choice:** Ref node + expand on click
**Notes:** User flagged that this conflicts with Phase 2 success criterion #1 ("renders fields inline, not just a label"). User chose to update the success criterion to match — $ref displays definition name with distinct style in Phase 2, inline expansion moves to Phase 3.

### Follow-up: Success Criterion Conflict

| Option | Description | Selected |
|--------|-------------|----------|
| Update the criterion | Change Phase 2 SC#1 to: "$ref nodes display definition name and are visually distinct; inline expansion in Phase 3" | ✓ |
| Expand inline after all | Go with "Expand with ref badge" to satisfy original criterion | |
| Default expanded | $ref renders fully expanded by default in Phase 2; Phase 3 adds collapse ability | |

**User's choice:** Update the criterion

---

## Required vs Optional

| Option | Description | Selected |
|--------|-------------|----------|
| Bold name text (Recommended) | Required property names in bold (fontWeight 700), optional in normal weight | ✓ |
| Color difference | Required gets brighter/white text, optional gets dimmer/gray | |
| Indicator icon | Small marker (bullet/asterisk) before required property names | |

**User's choice:** Bold name text
**Notes:** Leverages existing fontWeight "700" pattern from viewNameGraph. Subtle but consistent with monospace dark theme.

---

## Circular $ref Guard

| Option | Description | Selected |
|--------|-------------|----------|
| Show ref label + cycle icon (Recommended) | Display $ref node with name plus ↺ indicator; visited-set prevents recursion | ✓ |
| Truncate at depth limit | Allow expansion up to N levels, then show truncation marker | |
| You decide | Claude picks simplest approach with visited-set guard | |

**User's choice:** Show ref label + cycle icon
**Notes:** ↺ symbol is universally understood. Visited-set guard pattern prevents infinite recursion.

---

## SVG Viewport Sizing

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-fit with padding (Recommended) | Calculate diagram dimensions from coordinate-threading output, set viewBox dynamically | ✓ |
| Scrollable fixed-width | Fixed width, growing height with overflow-y scroll | |
| You decide | Claude picks based on existing coordinate-threading pattern | |

**User's choice:** Auto-fit with padding
**Notes:** Replaces hardcoded 520x520. Uses existing (Svg, Dimensions) return pattern to compute total bounds.

---

## Claude's Discretion

- Exact padding amount for auto-fit viewBox
- Visited-set implementation details (Set vs Dict, threading approach)
- ↺ symbol rendering method (SVG text vs Unicode)

## Deferred Ideas

None — discussion stayed within phase scope
