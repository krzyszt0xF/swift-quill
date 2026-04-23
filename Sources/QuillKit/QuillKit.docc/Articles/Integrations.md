# Integrations

Recipes for plugging syntax highlighters, image loaders, and streaming sources into Quill -- with worked examples for Nuke, Kingfisher, and LLM APIs.

@Metadata {
    @PageKind(article)
    @PageColor(orange)
}

## Overview

Quill's core is deliberately thin. Syntax highlighting, image loading, and streaming sources are behind protocols -- the bundled defaults cover common cases, and swapping in an existing pipeline is a matter of conforming to the relevant protocol.

This article covers three integration axes:

- **Syntax highlighting** -- replace or customize the bundled `SyntaxHighlighter.default` with your own highlighter backend.
- **Image loading** -- substitute Nuke, Kingfisher, or any image pipeline in place of the bundled `ImageLoader.default`.
- **Streaming sources** -- wire LLM APIs, WebSockets, or recorded playback into ``QuillStreamView``.

All three protocols are small (one required method each) and have no dependencies on Quill's internals beyond the input and output types.

## Syntax highlighting

Quill renders code blocks as plain styled text by default.
When a type conforming to ``SyntaxHighlighting`` is configured, fenced code blocks receive syntax-aware styling after the closing fence arrives (see <doc:SupportedMarkdown>).

### Using the bundled highlighter

The `QuillHighlight` target provides `SyntaxHighlighter.default`, a ready-to-use highlighter backed by HighlighterSwift and covering common languages (Swift, Python, JavaScript, TypeScript, JSON, HTML, CSS, and more):

```swift
import QuillHighlight

// SwiftUI
QuillStreamView(chunks: chunks, streamID: messageID)
    .quill.setHighlighter(SyntaxHighlighter.default)

// UIKit
quillView.syntaxHighlighter = SyntaxHighlighter.default
```

The bundled `SyntaxHighlighter` struct (from `QuillHighlight`) is currently only accessible via `SyntaxHighlighter.default`. To customize highlighting behavior beyond the default -- for example, to swap themes, restrict the language list, or layer post-processing on top -- implement the ``SyntaxHighlighting`` protocol directly. A common pattern is to wrap `SyntaxHighlighter.default` and augment or filter its output:

```swift
import QuillHighlight
import QuillKit
import UIKit

struct BrandedHighlighter: SyntaxHighlighting {
    func highlight(code: String, language: String) -> NSAttributedString? {
        guard let base = SyntaxHighlighter.default.highlight(code: code, language: language) else {
            return nil
        }
        let mutable = NSMutableAttributedString(attributedString: base)
        // Apply app-specific adjustments, for example override the background color.
        mutable.addAttribute(.backgroundColor, value: UIColor.secondarySystemBackground, range: NSRange(location: 0, length: mutable.length))
        return mutable
    }
}
```

### Writing a custom highlighter

Implement ``SyntaxHighlighting`` by providing `highlight(code:language:)`.
The protocol requires one method that takes a code string and a language identifier and returns an optional `NSAttributedString` with syntax-aware attributes applied:

```swift
import QuillKit

struct MyHighlighter: SyntaxHighlighting {
    func highlight(code: String, language: String) -> NSAttributedString? {
        // Your highlighting logic. Return nil to fall back to plain text rendering.
        let attributed = NSMutableAttributedString(string: code)
        // Apply foreground colors, font attributes, etc.
        return attributed
    }
}
```

Return `nil` when the language is unrecognized or highlighting fails -- Quill falls back to plain code block rendering.
Pass the custom highlighter the same way as the bundled default:

```swift
.quill.setHighlighter(MyHighlighter())
```

### Integrating an external highlighter backend

For highlighters like Highlight.js bindings, Tree-sitter parsers, or Pygments via network, wrap the backend call in the protocol method.
Keep in mind:

- `highlight(code:language:)` is invoked on a background queue after a code block's fence closes. Conformers must be `Sendable` and thread-safe. The returned `NSAttributedString` is applied on the main actor by Quill; return `nil` if highlighting cannot be produced synchronously.
- The `language` parameter is the raw language tag from the fence (for example, `swift`, `py`, `javascript`). Your highlighter maps these to its own language identifiers.
- If the language is empty or unrecognized by the backend, return `nil` -- users see the code plainly rather than an error state.

Example wrapping a tokenizing backend:

```swift
import QuillKit

struct ExternalBridgeHighlighter: SyntaxHighlighting {
    let backend: TokenizerClient // Verify against your tokenizer's API

    func highlight(code: String, language: String) -> NSAttributedString? {
        guard !language.isEmpty,
              let tokens = try? backend.tokenize(code, language: language) else {
            return nil
        }
        let attributed = NSMutableAttributedString()
        for token in tokens {
            attributed.append(NSAttributedString(string: token.text, attributes: token.attributes))
        }
        return attributed
    }
}
```

## Image loading

Quill displays placeholders for images by default.
Configuring an ``ImageLoading`` conformance enables async image fetching, caching, and rendering inline.

### Using the bundled loader

The `QuillImageLoader` target provides `ImageLoader.default`, a `URLSession`-backed loader:

```swift
import QuillImageLoader

// SwiftUI
QuillStreamView(chunks: chunks, streamID: messageID)
    .quill.setImageLoader(ImageLoader.default)

// UIKit
quillView.imageLoader = ImageLoader.default
```

### Integrating Nuke

Nuke is a widely used iOS image loading library.
Wrap Nuke's `ImagePipeline` in an ``ImageLoading`` conformance:

```swift
import Nuke
import QuillKit

struct NukeImageLoader: ImageLoading {
    let pipeline: ImagePipeline

    init(pipeline: ImagePipeline = .shared) {
        self.pipeline = pipeline
    }

    func loadImage(from url: URL) async throws -> UIImage {
        // Verify against Nuke 12.x API; current pattern returns PlatformImage (UIImage on iOS).
        try await pipeline.image(for: url)
    }
}
```

Pass it in the same pattern as the default:

```swift
.quill.setImageLoader(NukeImageLoader())
```

Nuke handles disk caching, memory caching, and format decoding.
Apps already using Nuke for other image loading can share the same pipeline state.

### Integrating Kingfisher

Kingfisher is another commonly used iOS image library.
Wrap `KingfisherManager`:

```swift
import Kingfisher
import QuillKit

struct KingfisherImageLoader: ImageLoading {
    func loadImage(from url: URL) async throws -> UIImage {
        // Verify against Kingfisher 7.x API.
        let result = try await KingfisherManager.shared.retrieveImage(with: url)
        return result.image
    }
}
```

### Writing a custom loader

For apps with existing image pipelines (internal services, authentication-required fetches), conform to ``ImageLoading`` directly:

```swift
import QuillKit

struct AuthenticatedImageLoader: ImageLoading {
    let authToken: String

    func loadImage(from url: URL) async throws -> UIImage {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
        return image
    }
}
```

Image loaders run on a background task; the returned `UIImage` is applied on the main actor by Quill internally.

## Streaming sources

``QuillStreamView`` consumes any `AsyncSequence<String>`. The source can be an LLM API, a WebSocket, a recorded stream, or any other async chunk producer.

### Integrating an OpenAI-style completions stream

Community OpenAI Swift SDKs expose completions as `AsyncStream`.
Transform the stream to yield text content as plain strings:

```swift
import Foundation

// Verify against your chosen OpenAI Swift SDK (for example, MacPaw/OpenAI).
func openAIChunks(prompt: String, apiKey: String) -> AsyncStream<String> {
    AsyncStream { continuation in
        Task {
            let client = OpenAIClient(apiKey: apiKey)
            do {
                for try await event in client.chatStream(prompt: prompt) {
                    if let delta = event.choices.first?.delta.content {
                        continuation.yield(delta)
                    }
                }
            } catch { }
            continuation.finish()
        }
    }
}
```

Consume it in ``QuillStreamView``:

```swift
QuillStreamView(
    chunks: openAIChunks(prompt: prompt, apiKey: Keys.openAI),
    streamID: messageID
)
```

### Integrating Anthropic streaming

Anthropic's streaming API uses Server-Sent Events.
A minimal pattern using raw `URLSession`:

```swift
import Foundation

struct AnthropicStreamEvent: Decodable {
    struct Delta: Decodable { let text: String? }
    let delta: Delta?
}

func anthropicChunks(prompt: String, apiKey: String) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            request.httpMethod = "POST"
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            // Verify against the current Anthropic API version header.
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.httpBody = try? JSONSerialization.data(withJSONObject: [
                "model": "claude-sonnet-4-20250514",
                "max_tokens": 4096,
                "stream": true,
                "messages": [["role": "user", "content": prompt]]
            ])

            guard let (bytes, _) = try? await URLSession.shared.bytes(for: request) else {
                continuation.finish(); return
            }
            for try await line in bytes.lines where line.hasPrefix("data: ") {
                let json = String(line.dropFirst(6))
                if let data = json.data(using: .utf8),
                   let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: data),
                   let text = event.delta?.text {
                    continuation.yield(text)
                }
            }
            continuation.finish()
        }
    }
}
```

``QuillStreamView`` accepts `AsyncThrowingStream` as well as `AsyncStream` -- either satisfies the `AsyncSequence<String>` requirement.

### Integrating a recorded stream

For demos, UI testing, or fallback content when the network fails, feed pre-recorded chunks:

```swift
import Foundation

func recordedChunks(_ text: String, pacing: TimeInterval = 0.02) -> AsyncStream<String> {
    AsyncStream { continuation in
        Task {
            for character in text {
                try? await Task.sleep(nanoseconds: UInt64(pacing * 1_000_000_000))
                continuation.yield(String(character))
            }
            continuation.finish()
        }
    }
}
```

Use it as a drop-in replacement for a live stream:

```swift
QuillStreamView(chunks: recordedChunks(cachedResponse), streamID: messageID)
```

Pair recorded streams with ``QuillStreamingPreset/snappy`` to ensure every chunk is visible -- useful for UI screenshot testing.

## Protocol reference summary

### ``SyntaxHighlighting``

```swift
public protocol SyntaxHighlighting: Sendable {
    func highlight(code: String, language: String) -> NSAttributedString?
}
```

One method.
`language` is the fence tag as written in the Markdown (may be empty).
Return `nil` to fall back to plain code block rendering when the language is unrecognized or highlighting fails.

### ``ImageLoading``

```swift
public protocol ImageLoading: Sendable {
    func loadImage(from url: URL) async throws -> UIImage
}
```

One method.
Async-throwing signature.
Runs on a background task; result applied on the main actor by Quill.

For full API details and extension points, see the protocol symbol pages.

## See Also

- <doc:GettingStarted> -- basic configuration and `.quill` modifier namespace
- <doc:CustomizingTheme> -- visual styling for code blocks and inline elements
- <doc:StreamingConcepts> -- the mental model behind ``QuillStreamView`` lifecycle
- <doc:SupportedMarkdown> -- per-element streaming behavior
- ``SyntaxHighlighting`` -- protocol symbol reference
- ``ImageLoading`` -- protocol symbol reference
