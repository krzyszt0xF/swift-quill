# QuillMarkdownView

A SwiftUI view that renders complete, static Markdown.

## Overview

``QuillMarkdownView`` is the SwiftUI counterpart for non-streaming content.
It renders a complete Markdown string in a single pass, using the same TextKit 2 renderer as ``QuillView`` and ``QuillStreamView``.

No streaming pipeline, no lifecycle, no `streamID` -- the view parses the Markdown once, renders, and stays stable until the content or configuration changes.
This makes it simpler to use than ``QuillStreamView`` for content that does not need streaming, without sacrificing visual quality.

Use ``QuillMarkdownView`` for:

- Help content and in-app documentation
- Saved chat messages displayed after a session ends
- Test fixtures for UI screenshots
- Any content already complete at render time

Avoid ``QuillMarkdownView`` for content you plan to stream later.
If the content is still arriving, ``QuillStreamView`` handles the lifecycle correctly.
Mixing the two by swapping views on completion is possible but introduces unnecessary view identity changes.

For content arriving in chunks, use ``QuillStreamView`` instead.
For the UIKit equivalent, use ``QuillView`` with the ``QuillView/markdown`` property.

### Environment modifiers

``QuillMarkdownView`` consumes the same `.quill` environment modifiers as ``QuillStreamView`` for link handling, syntax highlighting, and image loading.
See <doc:GettingStarted> for the modifier namespace.

### Visual parity with streaming output

Static and streaming rendering paths share the same parser, the same renderer, and the same theme system.
A completed stream and its equivalent static render produce visually identical output -- no "streaming mode looks different" surprises.

This matters for features like displaying saved chat history.
A rendered archive looks the same as the streamed original.
Swapping from ``QuillStreamView`` to ``QuillMarkdownView`` after a stream completes is visually indistinguishable; readers cannot tell the difference.

### Initializer

`init(markdown: String, configuration: QuillConfiguration = .default)` creates a static Markdown view.

- Parameter markdown: The complete Markdown content to render.
- Parameter configuration: Configuration controlling theme, streaming behavior, and image handling. Defaults to ``QuillConfiguration/default``. The streaming settings are ignored for static content but remain part of the configuration type for consistency with streaming views.

Use ``QuillConfiguration/default`` for most cases.
Customize only when theme or image handling needs to differ from defaults.
The `streaming` component of configuration has no effect here -- tail updates only apply during live streaming through ``QuillStreamView`` or ``QuillView/append(_:)``.

The Markdown is parsed and rendered once when the view first appears.
Changes to the `markdown` parameter cause re-parse and re-render.
Parsing happens on a background task; the rendered result applies on the main actor.
