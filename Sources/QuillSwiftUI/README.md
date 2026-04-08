# QuillSwiftUI

SwiftUI wrapper over QuillKit's UIKit rendering layer.

## Views

- **`QuillMarkdownView`** -- Static rendering. Pass a markdown string; updates when the string changes.
- **`QuillStreamView`** -- Streaming rendering. Consumes any `AsyncSequence<String>` and drives `QuillView` append/finish/error lifecycle.

## Stream identity

`QuillStreamView` does not diff `AsyncSequence` values (they are not `Equatable`). Use `.id(streamID)` with a value that changes each time you start a new stream. SwiftUI will tear down the old view and create a fresh one.

```swift
QuillStreamView(
    chunks: myStream,
    configuration: .init(
        streaming: .init(preset: .balanced)
    )
)
    .id(streamID)
```

## Dependencies

- **QuillKit** -- wraps `QuillView` via `UIViewRepresentable`
