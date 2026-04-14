# Quill Rendering Pipeline Architecture

The Quill rendering pipeline transforms raw markdown text into fully styled, interactive document views with support for streaming updates, syntax highlighting, and responsive layout. This document provides a comprehensive guide to the pipeline stages, configuration options, and integration patterns.

## Pipeline Overview

The pipeline follows a strict **unidirectional flow** from source text through parsing, reduction, rendering, and asynchronous enrichment. Each stage operates with explicit ownership boundaries and cancellation semantics.

> The core design principle is that later pipeline stages never influence earlier ones. This constraint enables safe concurrent operation and predictable streaming behavior.

The pipeline stages execute in sequence:

1. **Parse** -- converts raw markdown into a block-level AST
2. **Reduce** -- accumulates parsed events into a coherent document state
3. **Render** -- transforms the block AST into attributed string fragments and applies them to the text view
4. **Enrich** -- asynchronously loads syntax highlighting, images, and other expensive content

### Stage Isolation

Each stage maintains its own isolation context. The parser runs off the main actor inside a dedicated `MarkdownStreamController` actor. The reducer and renderer execute on `@MainActor` to safely mutate UIKit state. Enrichment tasks run on background threads with results delivered back to the main actor through coordinator objects.

This isolation model prevents data races without requiring manual locks or dispatch queue synchronization. The Swift concurrency runtime enforces these boundaries at compile time.

## Configuration

Quill provides a layered configuration system through the `QuillConfiguration` struct. Configuration changes applied while no stream is active trigger an immediate re-render of static content.

| Property | Type | Default | Description |
|:---------|:-----|:--------|:------------|
| `theme` | `QuillTheme` | `.default` | Visual styling for all block types |
| `tail` | `TailRevealPolicy` | `.smooth` | Controls streaming tail animation |
| `images` | `ImageConfiguration` | `.default` | Image loading and retry behavior |
| `layout` | `LayoutConfiguration` | `.default` | Height measurement and coalescing |
| `rendering` | `RenderConfiguration` | `.balanced` | Pipeline timing and buffering |
| `codeBlock` | `CodeBlockConfiguration` | `.default` | Code block styling and highlighting |

> **Note:** Configuration changes during an active stream are deferred until the next stream starts. The active stream continues with its frozen configuration snapshot to prevent mid-stream visual discontinuity.

### Theme System

The theme system controls the visual appearance of every block type through composable style descriptors:

```swift
struct QuillTheme: Sendable {
    var paragraph: ParagraphStyle
    var heading: HeadingStyle
    var codeBlock: CodeBlockStyle
    var blockQuote: BlockQuoteStyle
    var list: ListStyle
    var table: TableStyle
    var image: ImageStyle
    var thematicBreak: ThematicBreakStyle
    var inlineCode: InlineCodeStyle
    var link: LinkStyle
    var emphasis: EmphasisStyle
    var strong: StrongStyle
    var strikethrough: StrikethroughStyle

    static let `default` = QuillTheme(
        paragraph: .default,
        heading: .default,
        codeBlock: .default,
        blockQuote: .default,
        list: .default,
        table: .default,
        image: .default,
        thematicBreak: .default,
        inlineCode: .default,
        link: .default,
        emphasis: .default,
        strong: .default,
        strikethrough: .default
    )
}
```

Each style descriptor encapsulates font, color, spacing, and decoration properties for its block type. Themes are `Sendable` to allow safe sharing across isolation boundaries.

## Parsing

The parser converts raw markdown strings into an array of `BlockNode` values. It uses Apple's `swift-markdown` package as the underlying parser implementation, wrapped in a `MarkdownParser` struct that provides a clean `Sendable` interface.

### Block Types

The parser recognizes the following block-level elements:

- **Paragraphs** -- standard text content with inline formatting
- **Headings** -- levels 1 through 6 with inline content
- **Code blocks** -- fenced blocks with optional language identifiers
- **Block quotes** -- nested quote sections with recursive block content
- **Ordered lists** -- numbered list items with nested content
- **Unordered lists** -- bulleted list items with nested content
- **Task lists** -- checkbox items with checked/unchecked state
- **Tables** -- GFM pipe tables with column alignment
- **Thematic breaks** -- horizontal rule separators
- **Images** -- inline and reference-style image elements

### Inline Formatting

Within block-level elements, the parser handles inline formatting spans:

- `**bold**` and `__bold__` for strong emphasis
- `*italic*` and `_italic_` for regular emphasis
- `` `code` `` for inline code spans
- `[text](url)` for hyperlinks
- `~~strikethrough~~` for strikethrough text
- `![alt](url)` for inline images

The inline parser processes these spans recursively, producing a tree of `InlineNode` values that the renderer converts to attributed string attributes.

## Streaming Architecture

Streaming is the primary use case for Quill. When chunks of markdown arrive from an LLM or other streaming source, the pipeline processes them incrementally without re-parsing the entire document.

### Stream Lifecycle

A typical streaming session follows this lifecycle:

1. The host calls `append(chunk)` to deliver each markdown fragment
2. The stream controller actor buffers and parses incoming chunks
3. Parser events flow to the reducer, which maintains document state
4. The renderer applies incremental updates to the text view
5. The host calls `finish()` to flush remaining buffered content
6. The host may call `reset()` to clear state before the next session

### Module Stream Gate

The `ModuleStreamGate` controls when buffered content is committed to the rendering pipeline. It uses heuristics based on structural boundaries, accumulated text length, and time thresholds to determine optimal commit points.

> Block boundaries like headings, paragraph breaks, and code fence delimiters are natural commit points. The gate avoids splitting content mid-structure to prevent visual flicker.

The gate configuration allows tuning the trade-off between latency (how quickly new content appears) and coherence (how complete each visual update appears):

```json
{
  "minModuleLength": 50,
  "maxBufferingDelay": 1.5,
  "structureBoundaryPriority": "heading > paragraph > newline",
  "pendingStructureTypes": ["codeBlock", "table"]
}
```

When the gate detects a pending structure (such as an unclosed code fence), it holds all content until the structure completes, preventing partial rendering of complex blocks.

### Frozen and Tail Blocks

The streaming model separates blocks into two categories:

- **Frozen blocks** -- fully received blocks that will not change. These are rendered once and cached.
- **Tail block** -- the last block in the stream, which may receive additional content. This block is re-rendered on each update.

The frozen prefix grows monotonically as new block boundaries are detected. This ensures that previously rendered content remains stable while only the tail block is subject to incremental updates.

---

## Height Measurement

Quill uses a coalescing height measurement strategy to avoid expensive layout calculations on every content change. The `HeightCoordinator` debounces height update requests and skips redundant measurements when content revision and view width have not changed.

### Measurement Flow

The height measurement process follows these steps:

1. Content change triggers `scheduleHeightUpdate` on `HeightCoordinator`
2. The coordinator waits for the configured coalescing interval
3. After the interval, it checks whether content revision or width changed since last measurement
4. If changed, it measures the text view's intrinsic content size
5. If the height delta exceeds the notification threshold, it notifies the host

This approach reduces measurement frequency during rapid streaming while ensuring accurate final heights after content settles.

### Integration with Host Views

Host views receive height changes through the `onHeightChange` callback:

```swift
quillView.onHeightChange = { oldHeight, newHeight in
    // Animate constraint update or invalidate collection view layout
    UIView.animate(withDuration: 0.15) {
        self.heightConstraint.constant = newHeight
        self.view.layoutIfNeeded()
    }
}
```

The callback provides both old and new heights to support smooth animation transitions. Height changes are always delivered on the main actor.

## Syntax Highlighting

Code blocks receive syntax highlighting through the `SyntaxHighlighting` protocol. Quill ships with an optional `QuillHighlight` module that provides a default implementation using HighlighterSwift.

### Highlight Delivery

Highlights are delivered asynchronously after a code block is frozen:

1. The renderer detects a newly frozen code block with a language identifier
2. It schedules a highlight request through `HighlightCoordinator`
3. The coordinator dispatches the request to the configured `SyntaxHighlighting` implementation
4. When highlighting completes, the result is stored and the text view provider is notified
5. The provider applies the highlighted attributed string on its next layout pass

### Store and Sink Pattern

The highlight system uses a store/sink pattern for result delivery:

- The **store** holds highlight results durably, keyed by block identity
- The **sink** receives push notifications when new results arrive
- Text content providers pull from the store on `loadView` and register as sinks for future updates

This pattern handles both early completion (result ready before provider is created) and late completion (provider created before result arrives) without race conditions.

## Image Loading

Image elements in markdown are loaded asynchronously through the `ImageLoading` protocol. The default implementation in `QuillImageLoader` handles URL-based image fetching with caching and retry support.

### Aspect Ratio Updates

When an image finishes loading, its aspect ratio may differ from the placeholder. The image loading coordinator notifies the renderer, which invalidates the affected block's layout:

- Initial render uses a placeholder aspect ratio
- Image load completes with actual dimensions
- Coordinator fires `onAspectRatioChanged`
- Renderer invalidates height for the affected block
- Height coordinator schedules a new measurement

![Architecture diagram of the image loading pipeline](https://example.com/images/pipeline-architecture.png)

This ensures that the document layout adjusts smoothly as images load, without requiring a full document re-render.

![Sequence diagram showing streaming lifecycle](https://example.com/images/streaming-lifecycle.png)

## Rendering Internals

The `DocumentRenderer` converts block AST nodes into attributed string fragments and applies them to the backing `NSTextContentStorage`. It uses `TextKit 2` for text layout and rendering.

### Fragment Building

The `AttributedStringBuilder` walks the block AST and produces `RenderFragment` values for each block. Each fragment contains:

- The attributed string content for the block
- Provider descriptors for code blocks and tables
- Image attachment descriptors
- Block identity for cache invalidation

### Edit Transactions

Content updates are applied through edit transactions on the content storage. The renderer uses tail-only mutations to minimize the impact of streaming updates:

1. Frozen blocks are compared against the previous render state
2. Only changed or new blocks produce edit transactions
3. The tail block is always replaced in full on each render cycle
4. Edit transactions are batched to avoid redundant layout passes

This approach keeps the rendering cost proportional to the changed content rather than the total document size.

---

## Performance Characteristics

The pipeline is designed for smooth 60fps streaming with the following performance targets:

- Parse: sub-millisecond for typical streaming chunks
- Reduce: sub-millisecond for most block operations
- Render: under 4ms for tail-block updates, under 16ms for full document renders
- Height measurement: skipped for stable content, under 2ms when triggered

### Measurement Strategy

Performance is measured through:

1. **XCTest benchmarks** -- repeatable regression detection with maintained baselines
2. **os_signpost instrumentation** -- Instruments profiling for detailed pipeline analysis
3. **Physical device profiling** -- absolute threshold validation on reference hardware

### Known Bottlenecks

The following areas are known to require careful optimization:

- Static parse path currently runs synchronously on `@MainActor`
- Large code blocks with syntax highlighting can spike enrichment cost
- Complex tables with many columns increase attachment creation time
- Rapid configuration changes can trigger redundant re-renders

These bottlenecks are tracked and measured as part of the ongoing performance hardening effort.

## API Surface

The public API is intentionally small and focused on the streaming use case:

```swift
public final class QuillView: UIView {
    public var markdown: String?
    public var configuration: QuillConfiguration
    public var syntaxHighlighter: (any SyntaxHighlighting)?
    public var imageLoader: (any ImageLoading)?
    public var onHeightChange: ((_ old: CGFloat, _ new: CGFloat) -> Void)?
    public var onLinkSelection: ((URL) -> Void)?

    public func append(_ chunk: String)
    public func finish()
    public func reset()
    public func cancelStreaming()
}
```

This surface supports the complete lifecycle of static rendering, streaming, and interaction without exposing pipeline internals. Configuration changes are applied through the `configuration` property, which triggers re-rendering when appropriate.

### SwiftUI Integration

The `QuillSwiftUI` module provides a SwiftUI wrapper over `QuillView`:

- `QuillStreamView` for streaming use cases with `append`/`finish`/`reset` bindings
- Automatic height reporting through preference keys
- Configuration forwarding through environment values

The SwiftUI layer does not widen the public API -- it wraps the same capabilities exposed by `QuillView` in a declarative interface.
