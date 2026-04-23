![Quill wordmark](Docs/Assets/quill-wordmark.png)

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org) ![Platform](https://img.shields.io/badge/platform-iOS%2017+-blue.svg) ![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) ![CI](https://github.com/krzyszt0xF/swift-quill/actions/workflows/ci.yml/badge.svg) [![SPI](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fkrzyszt0xF%2Fswift-quill%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/krzyszt0xF/swift-quill) [![SPI Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fkrzyszt0xF%2Fswift-quill%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/krzyszt0xF/swift-quill)

**Render streaming Markdown in iOS chat UIs without rebuilding the document on every token.**

Quill is a streaming-first Markdown renderer for iOS, built for AI chat, assistants, coding tools, and any UI where Markdown arrives one chunk at a time. Native TextKit 2 rendering, no WebKit fallback.

## Table of Contents

- [Why Quill](#why-quill)
- [How Quill compares](#how-quill-compares)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Supported Markdown](#supported-markdown)
- [Streaming](#streaming)
- [Customization](#customization)
- [Optional Integrations](#optional-integrations)
- [Performance](#performance)
- [Documentation](#documentation)
- [Non-Goals](#non-goals)
- [Requirements](#requirements)
- [Contributing](#contributing)
- [License](#license)

## In 30 seconds

```swift
import QuillSwiftUI

QuillStreamView(
    chunks: myOpenAIStream,   // AsyncStream<String>
    streamID: message.id
)
```

That's it. No manual state management, no invalidation, no ScrollView tricks.

For UIKit, full setup, and more advanced usage, see [Quick Start](#quick-start) below.

## Why Quill

| Strength | What it means in an app |
|----------|-------------------------|
| Streaming-first pipeline | Incoming chunks render progressively without rebuilding the whole document. Only the active tail of the stream mutates on each chunk; complete blocks stay frozen. |
| Native iOS rendering | TextKit 2, UIKit selection, VoiceOver behavior, and Dynamic Type through customizable theme fonts. No WebKit fallback, no JavaScript. |
| Small integration surface | `QuillView` in UIKit, `QuillStreamView` in SwiftUI. Four methods for streaming: `append`, `finish`, `reset`, `cancelStreaming`. |
| Custom where it matters | Themes, link handling, syntax highlighting, image loading, and streaming presets. Bring your own or use the bundled defaults. |
| Evidence-backed performance | README numbers link to methodology, not marketing. Sub-millisecond main-thread work, zero dropped frames in extended streaming. |

## How Quill compares

Quill is designed for streaming Markdown from LLMs, not as a general-purpose Markdown library. If your use case is different, other libraries are likely a better fit:

- For **static Markdown in SwiftUI** with a rich theming DSL: [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) (iOS 15+).
- For **CSS-based theming and WebKit rendering** with highlight.js language coverage: [MarkdownView](https://github.com/keitaoouchi/MarkdownView).
- For **inline formatting only** (bold, italic, links in labels): Apple's built-in `AttributedString(markdown:)` in Foundation.

For a full comparison including streaming-capable alternatives and verified architectural analysis, see [Docs/CompetitiveResearch.md](Docs/CompetitiveResearch.md).

## Installation

Add Quill with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/krzyszt0xF/swift-quill.git", from: "1.0.0"),
]
```

Products: **QuillKit** (UIKit renderer), **QuillSwiftUI** (SwiftUI views), **QuillHighlight** (optional syntax highlighter), and **QuillImageLoader** (optional image loader). Most apps use **QuillSwiftUI** or **QuillKit**.

```swift
.target(name: "YourApp", dependencies: [
    .product(name: "QuillSwiftUI", package: "swift-quill"),
    .product(name: "QuillHighlight", package: "swift-quill"),
    .product(name: "QuillImageLoader", package: "swift-quill"),
])
```

## Quick Start

### SwiftUI

```swift compile
import SwiftUI
import QuillSwiftUI

struct ChatView: View {
    let chunks: AsyncStream<String>
    let messageID: UUID

    var body: some View {
        QuillStreamView(
            chunks: chunks,
            streamID: messageID,
            configuration: .init(streaming: .init(preset: .balanced), theme: .github)
        )
        .quill.onLinkTap { url in UIApplication.shared.open(url) }
    }
}
```

Use `streamID` when a fresh response starts -- QuillSwiftUI cancels the old subscription, resets content, and subscribes to the new stream when the identity changes. For static Markdown, use `QuillMarkdownView(markdown:)`.

### UIKit

```swift compile
import UIKit
import QuillKit

let quillView = QuillView(configuration: .init(streaming: .init(preset: .balanced), theme: .github))
quillView.onLinkSelection = { url in UIApplication.shared.open(url) }
quillView.append("# Streaming\n\n")
quillView.append("Markdown arrives in chunks.")
quillView.finish()
```

## Supported Markdown

Quill supports GFM (paragraphs, headings H1--H6, emphasis, inline code, links, images, unordered/ordered/task lists, blockquotes, fenced code blocks with highlighting, GFM tables, and thematic breaks). All inline content streams incrementally; tables and code blocks render after their closing token.

[Full support matrix and streaming caveats](https://swiftpackageindex.com/krzyszt0xF/swift-quill/documentation/quillkit/supportedmarkdown)

## Streaming

Quill renders only the active tail of the stream; complete blocks stay frozen. The API surface is four methods:

| Method | Effect |
|--------|--------|
| `append(_:)` | Append a Markdown chunk. |
| `finish()` | Flush buffered content and complete the stream. |
| `reset()` | Clear rendered content and start over. |
| `cancelStreaming()` | Cancel active work without clearing already-rendered content. |

[How streaming works: the frozen prefix / active tail model](https://swiftpackageindex.com/krzyszt0xF/swift-quill/documentation/quillkit/streamingconcepts)

## Customization

```swift compile
import UIKit
import QuillKit

// Token-based themes
var theme = QuillTheme.github
theme.body.font = .preferredFont(forTextStyle: .body)
theme.link.color = .systemBlue

// Streaming presets: .balanced (default), .snappy, .longForm,
// .custom(speedMultiplier:bufferingDelay:),
// .bufferedCustom(speedMultiplier:bufferingDelay:minModuleLength:)
let configuration = QuillConfiguration(
    streaming: .init(preset: .snappy),
    theme: theme
)
```

App-owned link handling via `.quill.onLinkTap { url in UIApplication.shared.open(url) }` (SwiftUI) or `quillView.onLinkSelection = { url in ... }` (UIKit).

[Theming guide](https://swiftpackageindex.com/krzyszt0xF/swift-quill/documentation/quillkit/customizingtheme) &#183; [Streaming presets](https://swiftpackageindex.com/krzyszt0xF/swift-quill/documentation/quillkit/streamingpresets)

## Optional Integrations

Syntax highlighting and image loading are optional. Without them, code blocks render as styled plain text and images keep their placeholder.

```swift
import QuillHighlight
import QuillImageLoader

// SwiftUI
.quill.setHighlighter(SyntaxHighlighter.default)
.quill.setImageLoader(ImageLoader.default)

// UIKit
quillView.syntaxHighlighter = SyntaxHighlighter.default
quillView.imageLoader = ImageLoader.default
```

Bring your own by conforming to `SyntaxHighlighting` or `ImageLoading`. [Integration recipes](https://swiftpackageindex.com/krzyszt0xF/swift-quill/documentation/quillkit/integrations)

## Performance

Measured on iPhone 15 Pro Max, iOS 26.4, Release build. Static render: under 1ms main-thread work (~870us). Streaming: 1.43ms average render, **zero dropped frames** across 2,552 updates. Memory: 0.75 MiB max variance across 3 stream-reset cycles. Parsing runs off the main thread; frozen-prefix architecture keeps per-chunk work bounded to the active tail. [Full methodology and raw measurements](Docs/Performance.md)

## Documentation

[API reference and guides](https://swiftpackageindex.com/krzyszt0xF/swift-quill/documentation/quillkit) on Swift Package Index. Roadmap: [ROADMAP.md](ROADMAP.md)

## Non-Goals

In v1.x:

- No Markdown editing -- Quill renders, it does not write.
- No WebKit fallback.
- No custom block plugin system.
- No LaTeX or math rendering.
- No row-by-row streamed tables (tables render after the closing row).
- No incremental code highlighting before the closing fence.
- No macOS, tvOS, watchOS, or visionOS support.

These are deliberate scope decisions. If you need any of these, see [How Quill compares](#how-quill-compares) above, or [Docs/CompetitiveResearch.md](Docs/CompetitiveResearch.md) for the full comparison.

## Requirements

| Requirement | Version |
|-------------|---------|
| iOS | 17.0+ (iPadOS 17.0+, Mac Catalyst 17.0+) |
| Swift | 6.0+ |
| Xcode | 16.0+ |

Quill is `Sendable`-conformant and safe under `-strict-concurrency=complete`.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, coding conventions, and the PR process.

## Security

Report security vulnerabilities via [GitHub's private vulnerability reporting](https://github.com/krzyszt0xF/swift-quill/security/advisories/new). See [SECURITY.md](SECURITY.md) for details on scope and response expectations.

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

## License

Quill is available under the MIT License. See [LICENSE](LICENSE).
