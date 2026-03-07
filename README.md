# swift-quill

A streaming-capable markdown rendering library for iOS.

> **Work in Progress** -- This library is under active development and not yet ready for production use.

## Architecture

swift-quill is organized as three layered targets with strict dependency boundaries:

```
QuillSwiftUI  ->  QuillKit  ->  QuillCore  ->  swift-markdown
(SwiftUI API)    (UIKit)       (Platform-agnostic)
```

- **[QuillCore](Sources/QuillCore/README.md)** -- Platform-agnostic markdown parsing and AST types. Depends on [swift-markdown](https://github.com/swiftlang/swift-markdown) but fully encapsulates it. Testable via `swift test` without a simulator.
- **[QuillKit](Sources/QuillKit/README.md)** -- UIKit rendering infrastructure built on TextKit 2 with per-block architecture.
- **[QuillSwiftUI](Sources/QuillSwiftUI/README.md)** -- SwiftUI wrappers providing idiomatic APIs for static and streaming markdown.

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
        .product(name: "QuillSwiftUI", package: "swift-quill"),
    ]
)
```

## License

swift-quill is available under the MIT license. See the [LICENSE](LICENSE) file for details.
