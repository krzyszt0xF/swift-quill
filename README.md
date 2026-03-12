# swift-quill

A streaming-capable markdown rendering library for iOS.

> **Work in Progress** -- This library is under active development and not yet ready for production use.

## Architecture

swift-quill is organized as three layered targets with strict dependency boundaries:

```
QuillSwiftUI  ->  QuillKit  ->  QuillCore  ->  swift-markdown
(SwiftUI API)    (UIKit API)   (Parsing layer)
```

- **[QuillCore](Sources/QuillCore/README.md)** -- Platform-agnostic markdown parsing, streaming infrastructure, and Block AST. All symbols are package-scoped. Depends on [swift-markdown](https://github.com/swiftlang/swift-markdown) but fully encapsulates it.
- **[QuillKit](Sources/QuillKit/README.md)** -- UIKit rendering and product API. Public surface is limited to `QuillView` and preset-based configuration.
- **[QuillSwiftUI](Sources/QuillSwiftUI/README.md)** -- SwiftUI wrapper over QuillKit. Provides `QuillMarkdownView` for static rendering and `QuillStreamView` for streaming via `AsyncSequence`.

## Usage

### SwiftUI

```swift
import QuillSwiftUI

// Static rendering
QuillMarkdownView(markdown: "# Hello\n\nSome **bold** text.")

// Streaming via AsyncSequence
QuillStreamView(chunks: myAsyncStream, preset: .balanced)
    .id(streamID) // required: use a new id each time you start a new stream
```

> **Note:** `QuillStreamView` does not diff the `AsyncSequence` value itself. Use `.id(streamID)` with a changing identity to restart streaming. SwiftUI will tear down the old view and create a fresh one.

### UIKit

```swift
import QuillKit

// Static rendering
let view = QuillView()
view.markdown = "# Hello\n\nSome **bold** text."

// Streaming
let streamView = QuillView(streamingPreset: .balanced)
streamView.append("# Title\n\n")
streamView.append("Streaming content...")
streamView.finish()

// Reset and reuse
streamView.reset()
```

### Presets

```swift
// Named presets
view.streamingPreset = .snappy    // Faster reveal
view.streamingPreset = .balanced  // Default
view.streamingPreset = .longForm  // Deliberate pacing

// Custom tuning
view.streamingPreset = .custom(
    speedMultiplier: 1.2,
    tailAggressiveness: .aggressive,
    bufferingDelay: 1.0
)
```

## Requirements

- iOS 17+
- Swift 6.0+
- Xcode 16+

## Installation

Add swift-quill as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/krzyszt0xF/swift-quill.git", from: "0.1.0"),
]
```

Then add the desired target to your module:

```swift
// UIKit
.target(name: "YourApp", dependencies: [
    .product(name: "QuillKit", package: "swift-quill"),
])

// SwiftUI
.target(name: "YourApp", dependencies: [
    .product(name: "QuillSwiftUI", package: "swift-quill"),
])
```

## License

swift-quill is available under the MIT license. See the [LICENSE](LICENSE) file for details.
