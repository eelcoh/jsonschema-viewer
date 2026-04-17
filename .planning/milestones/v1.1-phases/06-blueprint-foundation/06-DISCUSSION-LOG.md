# Phase 6: Blueprint Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 06-blueprint-foundation
**Areas discussed:** Background & color palette, Theme module scope, CSS vs SVG boundary, Input panel styling, Grid dot density & size, $ref dashed border on dark, Error state styling, Diagram panel CSS fallback

---

## Background Style

| Option | Description | Selected |
|--------|-------------|----------|
| Clean dark navy | Solid dark navy, no grid or texture | |
| Subtle grid blueprint | Dark navy with faint dot grid pattern | ✓ |
| Grid lines blueprint | Dark navy with thin line grid, classic blueprint paper | |

**User's choice:** Subtle grid blueprint
**Notes:** Evokes engineering blueprints with subconscious texture, not distracting graph paper.

---

## Node Colors on Dark Background

| Option | Description | Selected |
|--------|-------------|----------|
| Keep blue pills, brighten text | Keep #3972CE fill, brighten text to white | |
| Outlined nodes | Transparent fill, light borders, white text — classic blueprint | ✓ |
| Lighter blue pills | Brighter blue fill (#4a8fe0) with white text | |

**User's choice:** Outlined nodes
**Notes:** Classic blueprint look — shapes on dark canvas, not colored blocks.

---

## Connector Line Color

| Option | Description | Selected |
|--------|-------------|----------|
| Muted blue-gray | Subdued blue-gray (~#4a6a8a), blends with blueprint aesthetic | ✓ |
| Same as node border | Use same light color as node outlines — unified "ink" | |
| You decide | Claude picks the connector color | |

**User's choice:** Muted blue-gray
**Notes:** Creates visual hierarchy — connectors visible but don't compete with node borders.

---

## Theme Module Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Colors only | All color constants, no spacing/sizing | ✓ |
| Colors + spacing constants | Colors plus pillHeight, padding, font sizes, gaps | |
| Full design token system | Everything visual in one module | |

**User's choice:** Colors only
**Notes:** Keeps Phase 6 focused. Spacing can be centralized in a later phase if needed.

---

## CSS vs SVG Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| SVG background + grid | Full-bleed SVG rect for background AND grid pattern | ✓ |
| CSS background + SVG grid | CSS sets dark navy, SVG only handles grid overlay | |

**User's choice:** SVG background + grid
**Notes:** Self-contained in SVG output, exports cleanly if SVG download is ever added.

---

## Input Panel Styling

| Option | Description | Selected |
|--------|-------------|----------|
| Stay light | Keep input panel and toolbar light (#f6f8fa) | ✓ |
| Go dark everywhere | Dark theme for toolbar, input panel, and diagram | |
| Dark toolbar, light input | Dark toolbar, light input textarea | |

**User's choice:** Stay light
**Notes:** Clear visual separation between editing (light) and viewing (dark blueprint). Common dev tools pattern.

---

## Grid Dot Density & Size

| Option | Description | Selected |
|--------|-------------|----------|
| Subtle wallpaper | Small dots (r=0.5), wide spacing (~20px), barely visible | ✓ |
| Visible graph paper | Larger dots (r=1), tighter spacing (~15px), clearly a grid | |
| You decide | Claude picks dot size and spacing | |

**User's choice:** Subtle wallpaper
**Notes:** Dots fade into the background — subconscious texture, noticed but not distracting.

---

## $ref Dashed Border on Dark

| Option | Description | Selected |
|--------|-------------|----------|
| Keep dashed border | Same approach — solid vs dashed outline works on any background | ✓ |
| Dashed + dimmer color | Dashed border AND dimmer border color for double signal | |

**User's choice:** Keep dashed border
**Notes:** The solid-vs-dashed contrast is background-agnostic. No need to add a second signal.

---

## Error State Styling

| Option | Description | Selected |
|--------|-------------|----------|
| Keep in diagram area, adapt colors | Errors stay in diagram panel, light text on dark background | ✓ |
| You decide | Claude adapts error styling at discretion | |

**User's choice:** Keep in diagram area, adapt colors
**Notes:** Same layout, just color adjustments for dark background readability.

---

## Diagram Panel CSS Fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, match SVG background | Set .diagram-panel background to #1a2332 | ✓ |
| No, leave CSS white | Keep .diagram-panel white, SVG handles everything | |

**User's choice:** Yes, match SVG background
**Notes:** Prevents white flash before SVG renders.

---

## Claude's Discretion

- Exact hex values for all Theme colors (within the aesthetic direction: light borders, white text, muted connectors, subtle grid)
- SVG `<pattern>` implementation details for the dot grid
- Error display color specifics
- Exact grid dot sizing within the "subtle wallpaper" direction

## Deferred Ideas

None — discussion stayed within phase scope.
