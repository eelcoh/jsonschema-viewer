# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Elm 0.19.1 application that visually renders JSON Schema documents as SVG diagrams.

## Build & Dev Commands

- **Dev server:** `elm-live src/Main.elm --open --dir=public -- --output=public/elm.js` (requires `elm-live` — install with `npm i -g elm-live`)
- **Build:** `elm make src/Main.elm --output=public/elm.js --optimize && cp src/main.css public/main.css`
- **Run tests:** `elm-test`
- **Compile check:** `elm make src/Main.elm --output=/dev/null`
- **Serve static:** open `public/index.html` or use any static file server on `public/`

## Architecture

The app is a `Browser.element` with interactive JSON Schema input (textarea, file upload, example selector).

**Data flow:** JSON string → `Json.Schema.Decode.decoder` → `Json.Schema.Model` → `Render.Svg.view` → SVG output

Three-layer structure:

- **`Json.Schema`** — Type definitions for JSON Schema (Schema union type with Object, Array, String, Integer, Number, Boolean, Null, Ref, OneOf/AnyOf/AllOf variants). Also contains constructor functions and a `Definitions` dict (`Dict String Schema`) for `$ref` resolution.
- **`Json.Schema.Decode`** — JSON decoder that parses JSON Schema draft-07 into the `Schema` type. Uses `elm-json-decode-pipeline`. The `schemaDecoder` is recursive via `lazy`. `$ref` references and combinator schemas (oneOf/anyOf/allOf) are decoded as distinct variants.
- **`Render.Svg`** — Renders schemas as SVG pill-shaped nodes with icons indicating type (e.g., `{..}` for objects, `[..]` for arrays, `S` for strings). Recursively lays out properties/items horizontally. `$ref` nodes look up definitions but currently render as simple labels rather than expanding inline.

## Key Design Decisions

- `Definitions` keys are stored with full `#/definitions/` prefix (prepended during decode).
- `ObjectProperty` is a union type distinguishing `Required` vs `Optional` properties.
- The SVG renderer uses a coordinate-threading pattern where each view function returns `(Svg msg, Dimensions)` to enable layout calculation.
- `Main.elm` contains example JSON Schema strings organized via `exampleContent : ExampleSchema -> String`.
- Build output goes to `public/elm.js` and `public/main.css` (gitignored). The `public/` directory contains `index.html` which loads these directly.
