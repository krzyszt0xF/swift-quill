# Changelog

## Quill 1.0.0

*April 2026*

First public release. Quill is a streaming-capable markdown renderer for iOS, built on a single TextKit 2 document surface with native text selection and accessibility.

### Streaming

- Added smooth incremental rendering as streamed Markdown chunks arrive
- Added streaming presets: balanced (default), snappy, and long-form
- Added custom preset tuning with speed multiplier and buffering delay
- Added `QuillStreamingPreset.bufferedCustom(speedMultiplier:bufferingDelay:minModuleLength:)` for fine-grained tuning of module-buffered streaming (use alongside `StreamingMode.bufferedModules` for streams that emit very small chunks)
- Added `StreamingMode` enum exposing `.smoothedTail` (default) and `.bufferedModules`, selectable via `QuillConfiguration.Streaming.mode` for low-level streaming pipeline mode selection
- Added block-aware streaming with frozen prefix and active tail separation
- Added cancellation support for active streams

### Rendering

- Built on a unified TextKit 2 document surface
- Added heading rendering (H1-H6) with distinct sizes and weights
- Added paragraph rendering with bold, italic, strikethrough, and inline code
- Added ordered list, unordered list, and task list rendering with nesting
- Added blockquote rendering with bar decoration and nesting support
- Added horizontal rule rendering

### Code Blocks

- Added syntax-highlighted code blocks via pluggable `SyntaxHighlighting` protocol
- Added default syntax highlighter product (`QuillHighlight`) wrapping HighlighterSwift
- Added language label in code block header
- Added one-tap copy button with visual feedback
- Added graceful fallback for unsupported or missing languages

### Tables

- Added GFM table rendering with bordered cells and header styling
- Added column alignment (left, center, right)
- Added horizontal scroll for wide tables
- Added inline formatting in table cells
- Added copy and share support for table content

### Images

- Added async image loading via pluggable `ImageLoading` protocol
- Added default image loader product (`QuillImageLoader`) using URLSession
- Added configurable placeholder and error/retry views
- Added proportional scaling with aspect ratio preservation
- Added cancellation-safe loading during streaming

### Links

- Added tappable links with consumer callback
- Added link rendering inside all content types

### Themes

- Added token-based `QuillTheme` customization API
- Added default theme (GPT-inspired, light/dark adaptive)
- Added GitHub theme preset
- Added font-relative spacing values via `SpacingValue`

### Selection and Copy

- Added native text selection on the unified document surface
- Added copy to clipboard via standard iOS menu
- Added meaningful copy representations for code blocks and tables

### SwiftUI

- Added `QuillMarkdownView` for static rendering
- Added `QuillStreamView` for streaming via `AsyncSequence`
- Added `.quill.setHighlighter(_:)` environment modifier
- Added `.quill.setImageLoader(_:)` environment modifier
- Added `.quill.onLinkTap(_:)` modifier
- Added `.quill.onStreamFinished(_:)` modifier
- All modifiers use the `.quill` namespace pattern for clean View composition

### Performance

- Sub-millisecond main-thread rendering for static documents
- Zero dropped frames in extended streaming sessions
- Off-main parsing for non-blocking UI
- Bounded memory with no growth during repeated streaming

### Examples

- Added `Examples/QuillDemo`, an interactive SwiftUI playground app wired to the package via local path. Covers scenario selection, streaming presets, theme switching, and optional `SyntaxHighlighter` / `ImageLoader` integrations. iPhone portrait, iOS 17+.
