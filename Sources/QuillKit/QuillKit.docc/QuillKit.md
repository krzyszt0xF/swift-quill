# ``QuillKit``

**Streaming-first Markdown renderer for iOS, built for AI chat and assistants.**

## Overview

Quill renders Markdown progressively as chunks arrive, keeping complete blocks stable and mutating only the active tail.
It uses native TextKit 2 rendering with UIKit text selection, VoiceOver support, Dynamic Type through customizable theme fonts, and no WebKit fallback.
Configure `QuillTheme.body.font` with `.preferredFont(forTextStyle: .body)` or similar for accessibility-scaled text; see <doc:CustomizingTheme>.
Markdown parsing runs off the main thread; the rendered document updates on the main actor once parse results arrive.

Use Quill when your app receives Markdown content incrementally -- typically from an LLM streaming API -- and you want smooth rendering without the layout shifts, re-parsing costs, and jitter that come from rebuilding the document on every token.
Quill is intentionally narrow in scope: it renders, it does not edit, and it does not aim to replace general-purpose Markdown libraries.

Quill is organized as three public products:

- ``QuillView`` -- the UIKit renderer at the core of the package.
  Accepts streaming chunks through `append(_:)` and completes through `finish()`.
- ``QuillStreamView`` and ``QuillMarkdownView`` -- SwiftUI views backed by QuillKit.
  ``QuillStreamView`` consumes any `AsyncSequence<String>`; ``QuillMarkdownView`` renders static content.
- Two optional modules (``SyntaxHighlighting``, ``ImageLoading``) that ship as separate products.
  Add only what you need; both products have bundled default implementations.

For the mental model of how streaming works, see <doc:StreamingConcepts>.
To start integrating, see <doc:GettingStarted>.

## Featured

- <doc:GettingStarted>
- <doc:StreamingConcepts>

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:StreamingConcepts>

### Rendering Markdown

Views that render Markdown content, and the set of Markdown features Quill supports.

Most apps pick one of the three views depending on context: ``QuillView`` for UIKit, ``QuillStreamView`` when chunks arrive from an `AsyncSequence`, or ``QuillMarkdownView`` for static Markdown inside SwiftUI.

- ``QuillView``
- ``QuillStreamView``
- ``QuillMarkdownView``
- <doc:SupportedMarkdown>

### Streaming

Configuring how the active tail updates as chunks arrive.

``QuillConfiguration`` wraps the streaming and theme settings that `QuillView` and the SwiftUI wrappers accept.
Streaming presets cover the common pacing trade-offs: `.balanced` as the default, `.snappy` for faster tail updates, and `.longForm` for stability on large outputs.
A custom preset is available when the defaults do not fit.

- ``QuillConfiguration``
- <doc:StreamingPresets>

### Theming

- ``QuillTheme``
- <doc:CustomizingTheme>

### Integrations

Optional protocols and bundled products for syntax highlighting and remote images.

The `QuillHighlight` and `QuillImageLoader` products provide default implementations backed by HighlighterSwift and URLSession respectively.
Both protocols let you substitute your existing pipeline -- Nuke, Kingfisher, Highlight.js bindings, or anything else -- without touching Quill's core.

- ``SyntaxHighlighting``
- ``ImageLoading``
- <doc:Integrations>

### Advanced

Background on the architectural choices behind Quill's pipeline: the frozen-prefix / active-tail split, off-main parsing, and the deliberately small public API.

- <doc:DesignPhilosophy>
