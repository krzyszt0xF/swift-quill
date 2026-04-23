# Getting Started

Integrate Quill into a SwiftUI or UIKit app and render your first streaming Markdown response from an LLM.

@Metadata {
    @PageKind(article)
    @PageColor(green)
}

## Overview

This article walks through integrating Quill into a new or existing iOS app.
By the end, you'll have a view that renders Markdown as it streams from any `AsyncSequence<String>` source -- an LLM API, a WebSocket, a recorded playback, or a test fixture.

The walkthrough covers both SwiftUI (``QuillStreamView``) and UIKit (``QuillView``).
Both paths produce identical rendering; pick the one that matches your app's layer.
For the mental model of what happens behind the scenes, see <doc:StreamingConcepts>.
For static (non-streaming) Markdown, see the ``QuillMarkdownView`` section at the end of this article.

## Prerequisites

- iOS 17.0+, Swift 6.0+, Xcode 16+
- Quill added as a Swift Package Manager dependency (see [README Installation](https://github.com/krzyszt0xF/swift-quill#installation))
- At least one of: `QuillKit` (UIKit) or `QuillSwiftUI` (SwiftUI) imported in the target that will render Markdown
- An `AsyncSequence<String>` source of Markdown chunks -- this article assumes you have one; substitute your LLM API integration

## SwiftUI: render a streaming response

### Minimal setup

The simplest streaming view needs a chunk source and a stream identifier.

```swift
import SwiftUI
import QuillSwiftUI

struct ChatMessageView: View {
    let messageID: UUID
    let chunks: AsyncStream<String>

    var body: some View {
        QuillStreamView(
            chunks: chunks,
            streamID: messageID
        )
    }
}
```

That is enough to render streaming Markdown.
``QuillStreamView`` subscribes to `chunks`, delivers each element to the underlying ``QuillView``, and handles lifecycle automatically -- no manual `append`, `finish`, or `reset` calls needed.

### The streamID

`streamID` is how you tell ``QuillStreamView`` that a fresh response is starting.
The view uses SwiftUI's identity-driven lifecycle:

- When `streamID` stays the same, the view keeps its subscription and continues rendering incoming chunks into the existing content.
- When `streamID` changes, the view cancels the old subscription, resets rendered content, and subscribes to the new stream.

In an AI chat context, each assistant message should have its own stable identifier.
Use the message's unique identifier (usually a `UUID` from your data model) as `streamID`.
Do not use a timer, an index, or a hash of the chunks -- those cause unwanted resets mid-stream.

### Adding configuration

To control theming and streaming pacing, pass a `QuillConfiguration`:

```swift
QuillStreamView(
    chunks: chunks,
    streamID: messageID,
    configuration: .init(
        streaming: .init(preset: .balanced),
        theme: .github
    )
)
```

`QuillConfiguration` wraps everything app-specific: the theme, the streaming preset, and related tuning.
Create it once per message view or share one across messages -- Quill does not mutate it.

For the full set of themes, see <doc:CustomizingTheme>.
For presets, see <doc:StreamingPresets>.

### Handling link taps

Quill does not open links itself -- your app owns navigation.
Attach a handler with the `.quill.onLinkTap` modifier:

```swift
QuillStreamView(chunks: chunks, streamID: messageID)
    .quill.onLinkTap { url in
        UIApplication.shared.open(url)
    }
```

Validate the URL scheme before opening.
Quill delivers the raw URL from the Markdown -- if the stream is from an untrusted source, your handler is the security boundary.
Block `javascript:` and `data:` schemes unless you specifically expect them.

### Adding syntax highlighting

Code blocks render as styled plain text by default.
Add syntax highlighting by importing `QuillHighlight` and setting the highlighter via environment modifier:

```swift
import QuillHighlight

QuillStreamView(chunks: chunks, streamID: messageID)
    .quill.setHighlighter(SyntaxHighlighter.default)
    .quill.onLinkTap { url in UIApplication.shared.open(url) }
```

The default `SyntaxHighlighter` covers common languages (Swift, Python, JavaScript, JSON, HTML, and more).
For a custom highlighter, conform to the ``SyntaxHighlighting`` protocol and substitute your implementation.
See <doc:Integrations>.

### Adding image loading

Remote images render as placeholders by default.
Add loading by importing `QuillImageLoader`:

```swift
import QuillImageLoader

QuillStreamView(chunks: chunks, streamID: messageID)
    .quill.setImageLoader(ImageLoader.default)
    .quill.setHighlighter(SyntaxHighlighter.default)
```

The default `ImageLoader` uses `URLSession`.
To integrate Nuke, Kingfisher, or your existing image pipeline, conform to ``ImageLoading`` and substitute.
See <doc:Integrations>.

## UIKit: render a streaming response

``QuillView`` is the UIKit renderer.
Unlike SwiftUI's declarative binding, UIKit uses imperative methods: ``QuillView/append(_:)`` for each chunk, ``QuillView/finish()`` to close the stream.

### Minimal setup

```swift
import UIKit
import QuillKit

final class ChatMessageViewController: UIViewController {
    private let quillView = QuillView(
        configuration: .init(
            streaming: .init(preset: .balanced),
            theme: .github
        )
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        quillView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(quillView)
        NSLayoutConstraint.activate([
            quillView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            quillView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            quillView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            quillView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        quillView.onLinkSelection = { url in
            UIApplication.shared.open(url)
        }
    }
}
```

Apply the same URL scheme validation from the SwiftUI section to `onLinkSelection` -- the security boundary is identical.

### Streaming chunks

Connect your chunk source and feed each element into ``QuillView/append(_:)``:

```swift
func startStream(_ chunks: AsyncStream<String>) {
    Task {
        for await chunk in chunks {
            quillView.append(chunk)
        }
        quillView.finish()
    }
}
```

``QuillView`` is main-actor isolated. In UIKit controllers and views, call ``QuillView/append(_:)`` and ``QuillView/finish()`` directly from UI code.
If chunks are processed on a background actor, hop explicitly:

```swift
await MainActor.run {
    quillView.append(chunk)
}
```

### Resetting between messages

When a new response starts, clear the view first:

```swift
func startNewResponse(_ chunks: AsyncStream<String>) {
    quillView.reset()
    startStream(chunks)
}
```

``QuillView/reset()`` cancels any in-flight parsing, highlighting, or image loading tasks and clears the rendered content.
It is safe to call even if no stream is active.

### Cancellation

If the user taps "Stop generating" mid-stream, cancel without clearing:

```swift
func userTappedStop() {
    quillView.cancelStreaming()
}
```

``QuillView/cancelStreaming()`` preserves already-rendered content while stopping further updates.
See <doc:StreamingConcepts> for when to use ``QuillView/cancelStreaming()`` versus ``QuillView/reset()``.

### Adding integrations

Syntax highlighting and image loading use property assignment instead of SwiftUI modifiers:

```swift
import QuillHighlight
import QuillImageLoader

quillView.syntaxHighlighter = SyntaxHighlighter.default
quillView.imageLoader = ImageLoader.default
```

Same defaults and customization options as SwiftUI -- see <doc:Integrations>.

## Static Markdown (non-streaming)

For Markdown that is already complete at render time -- help content, saved chat messages, in-app documentation -- use ``QuillMarkdownView``:

```swift
import QuillSwiftUI

struct HelpView: View {
    let markdown: String

    var body: some View {
        QuillMarkdownView(markdown: markdown)
            .quill.onLinkTap { url in
                UIApplication.shared.open(url)
            }
    }
}
```

``QuillMarkdownView`` parses once and renders -- no streaming pipeline, no lifecycle, no `streamID`.
It uses the same theme, syntax highlighting, and image loading as ``QuillStreamView``, so the output is visually identical to a completed stream.

For UIKit static rendering, set `quillView.markdown = content` as a single assignment instead of calling ``QuillView/append(_:)`` and ``QuillView/finish()``.

## Next steps

- <doc:StreamingConcepts> -- the mental model behind Quill's streaming pipeline
- <doc:CustomizingTheme> -- tokens for body text, headings, links, code, blockquotes, tables
- <doc:StreamingPresets> -- pacing tuning for perceived streaming smoothness
- <doc:Integrations> -- Nuke, Kingfisher, OpenAI streams, custom highlighters, and other recipes
- <doc:SupportedMarkdown> -- element-by-element streaming behavior
