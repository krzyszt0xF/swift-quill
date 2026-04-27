# QuillSwiftUI

SwiftUI views backed by QuillKit's native TextKit 2 renderer.

## Streaming

```swift
import QuillSwiftUI

@State private var streamHandle = QuillStreamHandle()

QuillStreamView(
    chunks: viewModel.markdownChunks,
    streamID: viewModel.responseID,
    configuration: .init(
        streaming: .init(preset: .balanced),
        theme: .github
    ),
    handle: streamHandle
)
.quill.onLinkTap { url in
    UIApplication.shared.open(url)
}
.quill.onStreamFinished {
    viewModel.markResponseComplete()
}
```

`streamID` is the identity of the current response, run, or message. When it changes, QuillSwiftUI cancels the old subscription, resets the renderer, and starts consuming the new `AsyncSequence<String>`. No `.id(UUID())` workaround is needed.

For a "Stop generating" button, hold a ``QuillStreamHandle`` in `@State`, pass it into ``QuillStreamView``, and call `streamHandle.cancelStreaming()`.

## Static Markdown

```swift
QuillMarkdownView(
    markdown: "# Hello\n\nThis is **static** Markdown.",
    configuration: .init(theme: .github)
)
.quill.onLinkTap { url in
    UIApplication.shared.open(url)
}
```

## Optional Modifiers

All modifiers live under the `.quill` namespace and can be placed on or above the Quill view.

| Modifier | Required | Description |
|----------|----------|-------------|
| `.quill.onLinkTap { url in }` | No | Handles tapped Markdown links. |
| `.quill.onStreamFinished { }` | No | Runs when a stream finishes. |
| `.quill.setHighlighter(_:)` | No | Adds syntax highlighting for complete code blocks. |
| `.quill.setImageLoader(_:)` | No | Adds remote loading for standalone image blocks. |

Without a highlighter, code blocks render as styled plain text. Without an image loader, image blocks keep their loading placeholder.

```swift
import QuillHighlight
import QuillImageLoader

QuillStreamView(
    chunks: viewModel.markdownChunks,
    streamID: viewModel.responseID
)
.quill.setHighlighter(SyntaxHighlighter.default)
.quill.setImageLoader(ImageLoader.default)
```

## Views

| View | Description |
|------|-------------|
| `QuillMarkdownView` | Static Markdown rendering. Re-renders when the Markdown string changes. |
| `QuillStreamView` | Streaming Markdown rendering from any `AsyncSequence<String>`. |
| `QuillStreamHandle` | Imperative handle for actions such as `cancelStreaming()` on a live `QuillStreamView`. |

See the [root README](../../README.md) for installation, UIKit integration, performance notes, and examples.
