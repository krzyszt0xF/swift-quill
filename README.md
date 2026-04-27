# Quill

**Render streaming Markdown in iOS chat UIs without rebuilding the document on every token.**

<p>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift 6.0"></a>
  <img src="https://img.shields.io/badge/platform-iOS%2017+-blue.svg" alt="iOS 17+">
  <img src="https://img.shields.io/badge/SPM-compatible-brightgreen.svg" alt="SPM compatible">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="MIT License"></a>
  <img src="https://github.com/krzyszt0xF/swift-quill/actions/workflows/ci.yml/badge.svg" alt="CI">
  <a href="https://swiftpackageindex.com/krzyszt0xF/swift-quill">
    <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fkrzyszt0xF%2Fswift-quill%2Fbadge%3Ftype%3Dswift-versions" alt="Swift Package Index Swift versions">
  </a>
  <a href="https://swiftpackageindex.com/krzyszt0xF/swift-quill">
    <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fkrzyszt0xF%2Fswift-quill%2Fbadge%3Ftype%3Dplatforms" alt="Swift Package Index platforms">
  </a>
</p>

![Quill streaming Markdown demo](Docs/Assets/quill-in-action.gif)

Streaming-first Markdown renderer for AI chat and real-time UIs.  
Built on TextKit 2. No WebView. No full re-rendering.

<details>
<summary>Table of contents</summary>

- [Quill](#quill)
  - [In 30 seconds](#in-30-seconds)
  - [Why Quill](#why-quill)
  - [How Quill compares](#how-quill-compares)
  - [Installation](#installation)
  - [Quick Start](#quick-start)
    - [SwiftUI](#swiftui)
    - [UIKit](#uikit)
  - [Supported Markdown](#supported-markdown)
  - [Streaming](#streaming)
  - [Customization](#customization)
  - [Optional Integrations](#optional-integrations)
  - [Performance](#performance)
  - [Documentation](#documentation)
  - [Examples](#examples)
  - [Non-Goals](#non-goals)
  - [Requirements](#requirements)
  - [Contributing](#contributing)
  - [Security](#security)
  - [Code of Conduct](#code-of-conduct)
  - [License](#license)

</details>

## In 30 seconds

```swift
import QuillSwiftUI

QuillStreamView(
    chunks: openAIStream, // AsyncStream<String>
    streamID: message.id
)
```

That’s it. Stream in, render out - no state management required.

For UIKit, full setup, and more advanced usage, see [Quick Start](#quick-start) below.

## Why Quill

Most Markdown renderers rebuild the entire document on every update.

Quill doesn’t.

It updates only the active tail, keeping everything above stable.

| Strength | What it means in an app |
|----------|-------------------------|
| Streaming-first pipeline | Only the active tail updates as content streams in; completed blocks stay stable. |
| Native iOS rendering | TextKit 2 with native selection, accessibility, and Dynamic Type - no WebKit or JavaScript. |
| Small integration surface | Drop-in `QuillView` (UIKit) or `QuillStreamView` (SwiftUI) with 4 simple streaming methods. |
| Custom where it matters | Easily customize themes, links, syntax highlighting, and images - or use sensible defaults. |
| Evidence-backed performance | ~1 ms per update with zero dropped frames, even during long streaming sessions. |

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
    .package(url: "https://github.com/krzyszt0xF/swift-quill.git", from: "0.9.0"),
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

Quill supports GFM (paragraphs, headings H1-H6, emphasis, inline code, links, images, unordered/ordered/task lists, blockquotes, fenced code blocks with highlighting, GFM tables, and thematic breaks). All inline content streams incrementally; tables and code blocks render after their closing token.

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

*Measured on iPhone 15 Pro Max · iOS 26.4 · Release build*

| Metric | Result |
|--------|--------|
| Static render | ~0.87 ms (main thread) |
| Streaming render | ~1.43 ms avg |
| Frame drops | **0 across 2,552 updates** |
| Memory variance | ~0.75 MiB (3 stream cycles) |

Parsing runs off the main thread.  
Frozen-prefix architecture keeps per-chunk work bounded to the active tail.

[Full methodology and raw measurements](Docs/Performance.md)

## Documentation

[API reference and guides](https://swiftpackageindex.com/krzyszt0xF/swift-quill/documentation/quillkit) on Swift Package Index. Roadmap: [ROADMAP.md](ROADMAP.md)

## Examples

**[QuillDemo](Examples/QuillDemo/README.md)** — interactive playground app demonstrating configuration, streaming presets, themes, and integrations. Clone and run on iOS Simulator.

## Non-Goals

In v1.x:

- No Markdown editing - Quill renders, it does not write.
- No WebKit fallback.
- No custom block plugin system.
- No LaTeX or math rendering.
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
