# QuillKit

UIKit rendering and primary product API for swift-quill.

## Overview

QuillKit provides a unified document renderer built on TextKit 2. All markdown content -- paragraphs, headings, code blocks, tables, images, lists -- renders into a single `QuillView` that supports both static and streaming input.

## Key Types

| Type | Description |
|------|-------------|
| `QuillView` | Main UIKit view for static and streaming markdown rendering |
| `QuillConfiguration` | Top-level configuration for streaming behavior, images, and theme |
| `QuillTheme` | Visual theme with presets (`.default`, `.github`) and per-element token groups |
| `QuillStreamingPreset` | Named streaming presets: `.balanced`, `.snappy`, `.longForm`, `.custom(...)` |
| `StreamingMode` | Streaming strategy: `.smoothedTail` (character-level) or `.bufferedModules` (block-level) |
| `SyntaxHighlighting` | Protocol for providing syntax highlighting to code blocks |
| `ImageLoading` | Protocol for providing async image loading |

## Streaming Lifecycle

```swift
let view = QuillView(configuration: .default)

// Stream chunks as they arrive
view.append("# Hello\n")
view.append("This is **streaming** markdown.\n")

// Flush remaining buffered content
view.finish()

// Clear and start a new stream
view.reset()
```

Use `cancelStreaming()` to cancel an active stream without clearing rendered content.

## Configuration

```swift
var config = QuillConfiguration(
    streaming: .init(preset: .balanced),
    images: .init(retryEnabled: true),
    theme: .github
)
```

Optional integrations are injected through properties on `QuillView`:

```swift
view.syntaxHighlighter = SyntaxHighlighter.default  // from QuillHighlight
view.imageLoader = ImageLoader.default               // from QuillImageLoader
view.onHeightChange = { old, new in /* resize host */ }
view.onLinkSelection = { url in /* handle tap */ }
```

Without a syntax highlighter, code blocks render as styled plain text. Without an image loader, standalone image blocks keep their loading placeholder.

## Further reading

See the [root README](../../README.md) for installation, SwiftUI integration, and full documentation.
