# ``QuillView``

The UIKit view that renders Markdown text, with streaming support.

## Overview

``QuillView`` is Quill's core renderer. It accepts Markdown content either as a complete string (for static rendering) or as a sequence of chunks (for streaming). Rendering uses native TextKit 2, providing standard iOS text selection, VoiceOver, and Dynamic Type without WebKit overhead.

For the mental model of streaming behavior, see <doc:StreamingConcepts>. For integration recipes, see <doc:GettingStarted>.

### Static vs streaming usage

For content that is already complete at render time, assign to ``QuillView/markdown``:

```swift
let view = QuillView(configuration: .default)
view.markdown = "# Hello\n\nThis is **complete** Markdown."
```

For content that arrives in chunks, use ``QuillView/append(_:)`` followed by ``QuillView/finish()``:

```swift
let view = QuillView(configuration: .default)
view.append("# Hello\n\n")
view.append("This arrived in ")
view.append("multiple chunks.")
view.finish()
```

Do not mix static and streaming usage on the same view. Assigning ``QuillView/markdown`` resets any active stream, and calling ``QuillView/append(_:)`` after setting ``QuillView/markdown`` triggers a reset.

### Threading

``QuillView`` is main-actor isolated because it is a UIKit view.
Call its methods directly from UI code, which is already on `MainActor`.
From background actors, hop explicitly:

```swift
await MainActor.run {
    view.append(chunk)
}
```

Parsing runs on a background task; visible rendering updates apply on the main actor.

## Topics

### Creating a view

- ``init(frame:configuration:)``
- ``init(frame:)``

### Streaming

- ``append(_:)``
- ``finish()``
- ``reset()``
- ``cancelStreaming()``

### Static rendering

- ``markdown``
- ``accumulatedMarkdown``

### Configuration

- ``configuration``

### Extension points

- ``syntaxHighlighter``
- ``imageLoader``

### Callbacks

- ``onLinkSelection``
- ``onHeightChange``

## ``init(frame:configuration:)``

Creates a view with a given frame and configuration.

- Parameter frame: The view's initial frame. Defaults to `.zero`, suitable for Auto Layout.
- Parameter configuration: The configuration controlling theme, streaming behavior, and image handling. Defaults to ``QuillConfiguration/default``.

This is the recommended initializer. For most integrations, the frame default (`.zero`) combined with Auto Layout constraints is sufficient.

## ``init(frame:)``

Creates a view with a given frame using the default configuration.

- Parameter frame: The view's initial frame.

Provided for `UIView` compatibility. Most code should use ``init(frame:configuration:)`` instead, which allows specifying a custom configuration.

## ``append(_:)``

Appends a chunk of Markdown text to the active stream.

- Parameter chunk: The Markdown text to append. Can be any size -- a single character, a word, a paragraph, or an entire code block.

If no stream is active, the first call to ``append(_:)`` starts one. Parsing runs on a background task; visible rendering updates apply on the main actor.

If the chunk contains one or more complete blocks, those blocks promote to the frozen prefix atomically with the visible update. See <doc:StreamingConcepts> for the block promotion model.

## ``finish()``

Signals that the current stream has ended.

Any content still in the tail buffer flushes as final blocks. Enrichment tasks (syntax highlighting, image loading) continue in the background; ``finish()`` does not wait for them.

Call ``finish()`` when your upstream chunk source completes. For AsyncSequence-backed integrations using ``QuillStreamView``, this is handled automatically when the sequence ends.

## ``reset()``

Clears all rendered content and cancels in-flight work.

All parsing, highlighting, and image loading tasks cancel. The view returns to an empty state, ready to accept a new stream or static content. Safe to call even if no stream is active.

Call ``reset()`` when starting a new response that should replace the current one entirely. For ``QuillStreamView``, changing the `streamID` performs an equivalent reset automatically.

## ``cancelStreaming()``

Cancels active work without clearing rendered content.

The frozen prefix stays visible. The active tail stops updating. Enrichment tasks (highlighting, image loading) cancel.

Call ``cancelStreaming()`` when the user stops generation mid-stream and you want to preserve what has already rendered. See <doc:StreamingConcepts> for when to use ``cancelStreaming()`` versus ``reset()``.

Do not call ``finish()`` on a cancelled or errored stream -- ``finish()`` semantically means "the stream completed normally", and its block promotion rules may close blocks that were actually incomplete.

## ``markdown``

The complete Markdown content to render statically.

Assigning a value parses and renders the content in full. Setting ``markdown`` to a new value replaces previous content -- equivalent to ``reset()`` followed by full re-render.

Do not use ``markdown`` for streaming content. Use ``append(_:)`` and ``finish()`` instead.

## ``accumulatedMarkdown``

The current Markdown content, read-only.

For static rendering, returns the value assigned to ``markdown``. For streaming, returns the accumulated chunks from ``append(_:)`` calls so far. Returns `nil` before any content has been set.

## ``configuration``

The configuration controlling theme, streaming, and image handling.

- SeeAlso: ``QuillConfiguration``

Assigning a new configuration rebuilds internal state. For per-message configuration changes (for example, different streaming presets per response), create a new ``QuillConfiguration`` and assign it before the first ``append(_:)`` of the new response.

## ``syntaxHighlighter``

Optional syntax highlighter for fenced code blocks.

When set, code blocks receive syntax-aware styling after the closing fence arrives. Use `QuillHighlight.SyntaxHighlighter.default` for a ready-to-use highlighter, or provide a custom type conforming to ``SyntaxHighlighting``.

See <doc:Integrations> for recipes.

## ``imageLoader``

Optional image loader for standalone image blocks.

When set, images referenced by URL are loaded asynchronously and rendered inline. Use `QuillImageLoader.ImageLoader.default` for a `URLSession`-backed loader, or provide a custom type conforming to ``ImageLoading``.

See <doc:Integrations> for integration patterns with Nuke, Kingfisher, or custom pipelines.

## ``onLinkSelection``

A closure invoked when the user taps a link in rendered Markdown.

- Parameter url: The URL from the Markdown source. Not validated by Quill.

Validate the URL scheme before handling -- particularly for content from untrusted sources, block `javascript:` and `data:` schemes unless specifically expected.

## ``onHeightChange``

A closure invoked when the view's intrinsic height changes.

- Parameter old: The previous intrinsic content height.
- Parameter new: The new intrinsic content height.

Useful for containers that need to react to content-driven size changes (for example, scroll views adjusting scroll offsets during streaming).
