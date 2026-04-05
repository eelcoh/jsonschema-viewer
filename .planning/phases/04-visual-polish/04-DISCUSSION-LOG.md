# Phase 4: Visual Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-05
**Phase:** 04-visual-polish
**Areas discussed:** Connector line style, $ref node distinction, Line endpoints

---

## Connector Line Style

| Option | Description | Selected |
|--------|-------------|----------|
| Right-angle elbows | Horizontal from parent, vertical, horizontal to child. Classic XMLSpy style. | |
| Straight diagonal lines | Direct lines from parent edge to each child. Simpler but cluttered. | |
| Curved paths | Smooth bezier curves from parent to each child. Modern look. | ✓ |

**User's choice:** Curved paths
**Notes:** None

---

## Connector Line Color & Thickness

| Option | Description | Selected |
|--------|-------------|----------|
| Match existing lightClr | Same color as pill borders (#e6e6e6-ish). Consistent. Thin 1-1.5px. | |
| Subtle/muted gray | Lighter/more transparent than pill borders. Thin 1px. | |
| You decide | Claude picks something that works with the dark theme. | ✓ |

**User's choice:** You decide (Claude's discretion)
**Notes:** None

---

## $ref Node Distinction

| Option | Description | Selected |
|--------|-------------|----------|
| Dashed border | Same pill shape, dashed stroke instead of solid. Keeps '*' icon. | ✓ |
| Different background color | Slightly tinted fill color. Keeps solid border. | |
| Dashed border + link icon | Dashed border AND replace '*' with ↗ link symbol. Double signal. | |

**User's choice:** Dashed border
**Notes:** None

---

## Line Endpoints

| Option | Description | Selected |
|--------|-------------|----------|
| Right-center to left-center | Standard tree diagram convention. Left-to-right layout. | ✓ |
| Right-center to left-top | Attaches to top-left corner of child. More 'descending' feel. | |
| You decide | Claude picks best attachment points for curved paths. | |

**User's choice:** Right-center to left-center
**Notes:** None

---

## Claude's Discretion

- Connector line color and thickness
- Bezier curve control points
- strokeDasharray pattern for $ref dashed border
- Whether connector lines have rounded endpoints

## Deferred Ideas

None — discussion stayed within phase scope
