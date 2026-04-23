# ``QuillStreamView``

A SwiftUI view that renders streaming Markdown from an `AsyncSequence`.

## Overview

``QuillStreamView`` is the SwiftUI streaming counterpart to ``QuillView``.
It subscribes to a chunk source, delivers chunks to an underlying ``QuillView``, and manages lifecycle via SwiftUI's identity-driven update system.
No manual `append`, `finish`, or `reset` calls are required.

For the mental model of streaming, see <doc:StreamingConcepts>.
For a full SwiftUI integration walkthrough, see <doc:GettingStarted>.

### Relationship to ``QuillMarkdownView``

``QuillStreamView`` handles the streaming case.
``QuillMarkdownView`` handles static Markdown already complete at render time.
Both share the same theme, syntax highlighting, and image loading pipelines -- output is visually identical for equivalent final content.

Choose ``QuillStreamView`` when the content arrives progressively.
Choose ``QuillMarkdownView`` when the content is a complete string at view creation.

### Identity and streamID

SwiftUI's view identity drives stream lifecycle:

- When `streamID` stays the same, the view retains its subscription and continues rendering incoming chunks.
- When `streamID` changes, the view cancels the old subscription, resets rendered content, and subscribes to the new stream.

Use the message's stable identifier (typically a `UUID`) as `streamID`.
Do not use a timer, an index, or a hash of chunks -- those cause unwanted resets mid-stream.

The identity model matches SwiftUI's `.id()` modifier semantics.
If you are familiar with how view identity controls state recreation in SwiftUI, `streamID` behaves identically at the stream-subscription layer.

### Generic parameter

``QuillStreamView`` is generic over `S: AsyncSequence & Sendable where S.Element == String`.
It accepts both `AsyncStream<String>` and `AsyncThrowingStream<String, Error>`, as well as custom async sequence types that conform.
The generic over the sequence type avoids boxing overhead.

In practice, the LLM SDK you use provides an `AsyncStream`; pass it directly without wrapping.
If your upstream source is not an `AsyncSequence`, build one with `AsyncStream { continuation in ... }` and yield chunks from inside.
See <doc:Integrations> for worked examples.

### Configuration

Pass a ``QuillConfiguration`` to control theme, streaming preset, and image handling.
Defaults suit typical AI chat integrations; customization points are documented in ``QuillConfiguration``.

Configuration is read once when the view is first created.
To change configuration per message, create a new ``QuillConfiguration`` and pass it to a view bound to a new `streamID` -- the view rebuilds state for the new identity.
Mid-stream configuration changes on the same `streamID` may cause unintended visual resets.

### Error handling

If the chunk source throws, the stream ends and the `onError` closure (if provided) is invoked with the error.
Already-rendered content stays visible; only future chunks are affected.

Pair `onError` with your app's error UI to surface failures to the user.
Do not call ``QuillView/finish()`` in response to an error -- the partial content has already rendered, and `finish` semantics ("stream completed normally") do not apply.
The preserved partial content is Quill's way of handling the "stream stopped unexpectedly" case.

## Topics

### Creating a stream view

- ``init(chunks:streamID:configuration:onError:)``

### Internal coordination

- ``Coordinator``

## ``init(chunks:streamID:configuration:onError:)``

Creates a streaming Markdown view.

- Parameter chunks: The source of Markdown chunks. Any `AsyncSequence<String>` conforming to `Sendable`. Can be finite (completes when the sequence ends) or effectively infinite (runs until `streamID` changes or the view is deallocated).
- Parameter streamID: A stable identifier for this stream. When the ID changes, the view resets and subscribes to the new stream. Defaults to `nil`.
- Parameter configuration: Configuration controlling theme, streaming behavior, and image handling. Defaults to ``QuillConfiguration/default``.
- Parameter onError: Optional closure invoked if the stream throws. Defaults to `nil`.

For typical AI chat use, pass the message's unique identifier as `streamID` so new responses replace previous ones cleanly.
The view handles the subscription lifetime automatically when `streamID` changes.

The `onError` parameter is invoked once if the sequence throws.
It is not invoked for normal completion (non-throwing end of sequence) -- for completion signals, observe when the sequence finishes in your upstream code.

## ``Coordinator``

The coordinator managing the underlying ``QuillView`` instance and stream subscription.

``Coordinator`` is an implementation detail exposed because SwiftUI's `UIViewRepresentable` protocol surfaces it.
It manages the lifetime of the chunk subscription and delivers chunks to the underlying ``QuillView``.
The coordinator also handles `streamID` changes by cancelling the previous subscription and starting a new one on the existing underlying view.

Applications typically do not interact with ``Coordinator`` directly.
It is documented here because it appears in the public symbol graph.

The coordinator holds a reference to the ``QuillView`` it manages, allowing SwiftUI to re-use the same underlying UIKit view across state updates.
This avoids repeatedly re-creating ``QuillView`` instances and preserves internal streaming state across SwiftUI's body re-evaluations.
