# Streaming Concepts

The mental model for using Quill's streaming API: what happens when chunks arrive, why only the tail mutates, and which lifecycle method to call when.

@Metadata {
    @PageKind(article)
    @PageColor(blue)
}

## Overview

LLM streaming produces Markdown incrementally -- sometimes character by character, sometimes chunk by chunk of varying sizes.
Naive rendering re-parses and re-renders the entire accumulated document on every chunk.
For a 500-line response, this means re-parsing 500 lines 500+ times as it grows.
The user-visible result is layout jumps, dropped frames, and memory churn.

Quill splits the rendered document into two conceptual zones.
A frozen prefix holds complete blocks that no longer change; an active tail holds the in-progress content after it.
Each chunk mutates only the tail.
The frozen prefix never re-parses, never re-measures, and never re-renders.

The consequence is that per-chunk work is bounded by tail size -- typically a few hundred bytes -- not by document size.
Frame time stays flat as the document grows.

## The two zones

<!-- TODO: streaming-architecture.svg needs professional iteration. Current version is placeholder quality. -->
![Streaming architecture diagram showing chunk flow from input through parser to frozen prefix and active tail](streaming-architecture)

At any moment during streaming, Quill splits the rendered document into two regions.

### Frozen prefix

Complete blocks -- paragraphs whose closing newline has arrived, code blocks past their closing fence, tables past their closing row.
Once a block joins the frozen prefix, Quill does not touch it.
No re-parsing.
No re-measurement.
No attributed-string mutations.
The text fragments in TextKit 2 for that region stay stable for the rest of the stream.

### Active tail

The in-progress content after the frozen prefix.
The tail may be a single paragraph mid-sentence, an open code block still receiving lines, or a partial list item.
When ``QuillView/append(_:)`` delivers a new chunk, only the tail re-parses and re-renders.
When the tail produces a new complete block -- a newline closes a paragraph, a closing fence ends a code block -- that block joins the frozen prefix and the tail resets to what follows it.

This split is not a lossy optimization; it is exact.
The tail is parsed in full each chunk.
The frozen prefix never needs to re-parse because, by definition, nothing in it has changed.

## The lifecycle

The streaming API exposes four methods on ``QuillView``. SwiftUI wrappers (``QuillStreamView``) drive the same lifecycle automatically from an `AsyncSequence<String>`.

### `append(_:)`

``QuillView/append(_:)`` delivers a Markdown chunk to the stream.
The chunk is appended to the tail buffer.
Parsing runs off the main thread; when it completes, the rendered document updates on the main actor.
If the chunk contains one or more complete blocks, those blocks promote into the frozen prefix atomically with the render update.

Chunks can be any size.
A single character, a word, a full paragraph, or an entire code block -- the pipeline handles all of them.
For an AsyncSequence-backed SwiftUI integration, ``QuillStreamView`` calls ``QuillView/append(_:)`` once per element in the sequence.

### `finish()`

``QuillView/finish()`` signals that the stream has ended.
Any content still in the tail buffer flushes as final blocks.
Enrichment tasks (syntax highlighting, image loading) continue in the background -- ``QuillView/finish()`` does not wait for them.

Call ``QuillView/finish()`` when your upstream `AsyncSequence` completes, when the LLM API signals `[DONE]`, or when you want to commit whatever has arrived so far as the final render.

### `reset()`

``QuillView/reset()`` clears all rendered content and cancels any in-flight work -- parsing, highlighting, image loading.
The view returns to an empty state, ready to accept a new stream.

Call ``QuillView/reset()`` when starting a new response that should replace the current one entirely. In SwiftUI, changing the `streamID` on ``QuillStreamView`` performs an equivalent reset automatically.

### `cancelStreaming()`

``QuillView/cancelStreaming()`` cancels active work without clearing already-rendered content.
The frozen prefix stays visible.
The tail stops updating.
Enrichment tasks cancel.

Call ``QuillView/cancelStreaming()`` when the user taps "Stop generating" and you want to preserve what has already arrived rather than discard it.

## When things join the frozen prefix

The promotion rule is: a block joins the frozen prefix once its closing token arrives. The exact trigger varies by block type.

| Block type | Promotes when... |
|-----------|------------------|
| Paragraph | A blank line follows the paragraph. |
| Heading | The newline ending the heading line arrives. |
| List item | A blank line or a non-list line follows. |
| Code block | The closing fence arrives on its own line. |
| Blockquote | The blockquote prefix stops appearing on subsequent lines. |
| Table | The last row of the table arrives and a blank line follows. |
| Thematic break | Immediate -- thematic breaks are single-line blocks. |

Until promotion, a block is part of the active tail.
If a chunk delivers a heading followed by two paragraphs, the heading and first paragraph promote (they are complete); the second paragraph stays in the tail until its own terminator arrives.

This matters for two reasons.
First, syntax highlighting on code blocks only applies after the fence closes -- until then, the code block renders as unstyled text inside the tail.
Second, tables render as a single unit after the closing row; row-by-row streaming is not supported.
See <doc:SupportedMarkdown> for the full list of block-level streaming behaviors.

## What runs off the main thread

Markdown parsing is CPU work that scales with chunk size.
Running it on the main thread during streaming would contend with the render loop and cause dropped frames.
Quill parses each chunk on a background `Task`, then applies the rendered result to the view on the main actor.

This has two user-visible consequences:

- **Parse latency never blocks the render loop.** Even for large chunks, frame time stays stable because parsing happens off-main.
- **Render application is always on the main actor.** ``QuillView`` is main-actor isolated, so UI code can call its methods directly. Background actors should hop explicitly with `await MainActor.run { view.append(chunk) }` before interacting with the view.

The implementation details -- task lifetime, cancellation propagation, `Task.isCancelled` guards after `await` -- are documented in [Docs/Performance.md](https://github.com/krzyszt0xF/swift-quill/blob/main/Docs/Performance.md#why-quill-is-fast).

## Common lifecycle patterns

### New response replaces old

The user sends a new message; the assistant starts a new response.
Old content should clear; new chunks should flow into a blank view.

In SwiftUI, change the `streamID` on ``QuillStreamView``.
The view detects the identity change, cancels the old subscription, resets, and subscribes to the new stream automatically.
No manual ``QuillView/reset()`` needed.

In UIKit, call ``QuillView/reset()`` before the first ``QuillView/append(_:)`` of the new response.

### User cancels mid-stream

The user taps "Stop generating" before the response completes.
The already-rendered content should stay visible; no more updates should arrive.

Call ``QuillView/cancelStreaming()``.
The frozen prefix stays.
The partially-rendered tail stops at its current state.
If you later decide to resume with different content, call ``QuillView/reset()`` first.

### Stream errors out

Upstream throws before completion -- network failure, rate limit, or similar.
Some content has rendered; the rest will never arrive.

Call ``QuillView/cancelStreaming()`` to stop work, then show an error UI alongside the rendered content.
Do not call ``QuillView/finish()`` -- ``QuillView/finish()`` semantically means "the stream completed normally", and its promotion rules may close blocks that were actually incomplete.
``QuillView/cancelStreaming()`` preserves the "stopped mid-stream" state accurately.

### Replaying a recorded stream

You want to show a cached response as if it were streaming, for demos or UI testing.
Feed the recorded chunks through ``QuillView/append(_:)`` with whatever pacing makes sense, then ``QuillView/finish()``.
The streaming presets (see <doc:StreamingPresets>) control perceived pacing within Quill; your pacing between ``QuillView/append(_:)`` calls controls the external rhythm.

## See Also

- <doc:GettingStarted> -- step-by-step integration for SwiftUI and UIKit
- <doc:StreamingPresets> -- tuning perceived pacing of tail updates
- <doc:SupportedMarkdown> -- block-by-block streaming behavior
- ``QuillView`` -- the UIKit renderer
- ``QuillStreamView`` -- the SwiftUI streaming wrapper
