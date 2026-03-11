# QuillKit

UIKit rendering and product API for swift-quill.

## Purpose

QuillKit provides the UIKit rendering layer with a per-block architecture. Each block-level markdown element is rendered as its own view, enabling efficient incremental updates during streaming.

## Public API

The public surface is intentionally minimal:

- `QuillView` -- Main view for both static and streaming markdown rendering
  - `markdown` -- Set static markdown content
  - `append(_:)` / `finish()` / `cancelStreaming()` / `reset()` -- Streaming lifecycle
  - `currentMarkdown` -- Read-only snapshot of raw input
  - `streamingPreset` -- Preset-based configuration
  - `onHeightChange` -- Height change callback
- `QuillStreamingPreset` -- Named presets (`.balanced`, `.snappy`, `.longForm`) and `.custom(...)`
- `TailAggressiveness` -- Custom preset parameter (`.aggressive`, `.balanced`, `.conservative`)

## Pipeline

```
Markdown -> Block AST -> FlowSegmentBuilder -> RenderTree -> Renderer
```

All pipeline internals (renderers, sequencers, configuration structs) are internal to QuillKit.

## Dependencies

- **QuillCore** -- Consumes the Block AST and streaming infrastructure
