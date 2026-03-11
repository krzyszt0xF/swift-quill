# swift-quill

A streaming-capable markdown rendering library for iOS.

> **Work in Progress** -- This library is under active development and not yet ready for production use.

## Architecture

swift-quill is organized as three layered targets with strict dependency boundaries:

```
QuillSwiftUI  ->  QuillKit  ->  QuillCore  ->  swift-markdown
(SwiftUI stub)   (UIKit API)   (Parsing layer)
```

- **[QuillCore](Sources/QuillCore/README.md)** -- Platform-agnostic markdown parsing, streaming infrastructure, and Block AST. All symbols are package-scoped. Depends on [swift-markdown](https://github.com/swiftlang/swift-markdown) but fully encapsulates it.
- **[QuillKit](Sources/QuillKit/README.md)** -- UIKit rendering and product API. Public surface is limited to `QuillView` and preset-based configuration.
- **[QuillSwiftUI](Sources/QuillSwiftUI/README.md)** -- Minimal SwiftUI target. Real wrapper work is deferred to a future phase.

## Usage

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
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "QuillKit", package: "swift-quill"),
    ]
)
```

## License

swift-quill is available under the MIT license. See the [LICENSE](LICENSE) file for details.
