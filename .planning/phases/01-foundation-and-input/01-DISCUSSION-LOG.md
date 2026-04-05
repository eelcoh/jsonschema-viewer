# Phase 1: Foundation and Input - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-03
**Phase:** 01-foundation-and-input
**Areas discussed:** Page layout, Input behavior, Error presentation, Sample schemas

---

## Page Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Side-by-side | Textarea on the left, SVG diagram on the right. Classic schema-tool layout. | |
| Stacked (top/bottom) | Input area on top (collapsible), diagram fills the rest below. | |
| Input-then-diagram | Full-page input screen, then switch to diagram-only view. | |

**User's choice:** Side-by-side, but with the textarea collapsible/closeable
**Notes:** User wants the textarea visible by default but with ability to close it to maximize diagram space.

### Follow-up: Textarea visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Always-visible textarea | Textarea always shows current JSON. User can edit live. | |
| Minimal input bar | Just paste/upload buttons, raw JSON hidden after loading. | |

**User's choice:** Visible, but it would be nice if it can be closed
**Notes:** User specifically requested collapsible behavior — not just always-visible.

### Follow-up: Update behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Live update | Diagram re-renders on every change to textarea content. | |
| Manual render button | User clicks 'Render' to update the diagram. | |

**User's choice:** Live update

---

## Input Behavior

### File upload method

| Option | Description | Selected |
|--------|-------------|----------|
| Upload button | Dedicated button that opens file picker. | |
| Drag-and-drop zone | Drag .json file onto the textarea/diagram area. | |
| Both button and drag-drop | Upload button plus drag-and-drop. | |

**User's choice:** Drag-and-drop zone
**Notes:** Requires ports/JS interop in Elm.

### Hardcoded test schemas

| Option | Description | Selected |
|--------|-------------|----------|
| Remove them | Delete hardcoded strings, app starts empty. | |
| Keep as sample data | Move to separate module, make selectable. | |

**User's choice:** Remove them

### Initial state

| Option | Description | Selected |
|--------|-------------|----------|
| Empty with placeholder text | Textarea empty with hint text, diagram shows welcome. | |
| Pre-loaded example | Start with small example schema so user sees diagram immediately. | |

**User's choice:** Pre-loaded example

---

## Error Presentation

### Error location

| Option | Description | Selected |
|--------|-------------|----------|
| Replace diagram area | Error message appears where diagram would be. | |
| Below the textarea | Error under input area, diagram stays empty or shows last render. | |
| Inline in textarea | Highlight error location in textarea like a code editor. | |

**User's choice:** Replace diagram area

### Transient error handling

| Option | Description | Selected |
|--------|-------------|----------|
| Keep last valid diagram | While JSON invalid, keep showing last successful render. Show errors after pause. | |
| Show error immediately | Replace diagram with error on every keystroke producing invalid JSON. | |
| You decide | Claude picks best approach. | |

**User's choice:** Keep last valid diagram

---

## Sample Schemas

### Example schema count

| Option | Description | Selected |
|--------|-------------|----------|
| One built-in example | Single small example on startup. | |
| Dropdown with examples | 2-3 examples demonstrating different capabilities. | |
| You decide | Claude picks based on complexity and scope. | |

**User's choice:** Dropdown with examples

---

## Claude's Discretion

- Debounce timing for live updates
- Specific example schemas to include
- Visual styling of textarea collapse control
- Drag-and-drop visual feedback

## Deferred Ideas

None — discussion stayed within phase scope
