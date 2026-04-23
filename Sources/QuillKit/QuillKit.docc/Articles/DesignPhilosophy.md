# Design Philosophy

Why Quill is the way it is: the architectural decisions, scope boundaries, and design priorities behind the library.

@Metadata {
    @PageKind(article)
    @PageColor(purple)
}

## Overview

Quill is a streaming-first Markdown renderer for iOS.
That single-sentence description rules out many things: Quill is not a general-purpose Markdown library, not an editor, not a cross-platform solution, and not a canvas for visual experimentation.
These exclusions are intentional.
Being narrow makes Quill good at one thing.

This article explains the design choices behind that narrowness: which things Quill does and does not do, why the architectural split between a frozen prefix and an active tail was chosen, why the public API is small, and how the v1.0 scope boundary was drawn.
It does not explain how to use Quill -- see <doc:GettingStarted> for that -- nor does it document every feature -- see <doc:SupportedMarkdown>.

Readers should come away with two things: an understanding of why Quill works the way it does, and enough context to judge whether Quill's priorities match their project's needs.
If they match, the rest of the documentation explains how to integrate.
If they do not, [Docs/CompetitiveResearch.md](https://github.com/krzyszt0xF/swift-quill/blob/main/Docs/CompetitiveResearch.md) lists alternatives that take different tradeoffs.

## Streaming-first is the organizing principle

Quill exists because rendering Markdown as it streams from an LLM is substantively different from rendering a complete Markdown document.
A library optimized for static rendering can be made to handle streams, but the result is either slow (re-parsing the full document on every chunk) or visually jarring (layout jumps as completed blocks are re-measured).

The frozen prefix / active tail split is Quill's answer.
Completed blocks freeze -- no re-parse, no re-measurement, no attributed-string churn.
The tail parses on every chunk, but the tail is small.
Per-chunk work is bounded by tail size, not document size.
See <doc:StreamingConcepts> for the full model.

This architecture is not a premature optimization.
It is the foundation that makes Quill worth using.
Every other design choice in the library -- the small public API, the narrow feature set, the emphasis on native rendering -- flows from the commitment to streaming-first.

### Why not a generic Markdown renderer with streaming tacked on?

Three practical reasons:

- **Re-parsing cost.**
  A generic parser processes the full document on each update.
  For a 500-line response streamed in 500 chunks, that is 500 full parses -- quadratic work for linear content growth.
  The cost is invisible on short content and crippling on long content; the failure mode is latent until it isn't.
- **Layout thrash.**
  A generic renderer re-measures completed blocks on every content change, because the renderer cannot distinguish "this block is final" from "this block might still change".
  The user sees layout jumps as line breaks shift and margins recompute.
  On large documents, the cumulative effect looks like the content is still settling long after the text itself has stopped changing.
- **Highlighting drift.**
  Syntax highlighters applied mid-stream produce incorrect results on incomplete code.
  A generic renderer that applies highlighting on every update must either accept incorrect highlighting or delay highlighting in an ad-hoc manner.
  Quill's block-close promotion gives highlighting a natural trigger point: run the highlighter once when the fence closes, not on every chunk arriving between fences.

Quill does not retrofit streaming onto a generic renderer.
It starts from streaming and asks: what is the minimum architecture required to render Markdown progressively without the three failure modes above?
The answer is the frozen prefix / active tail model.

## The public API is deliberately small

Quill exposes roughly 28 public types across four public modules (QuillKit, QuillSwiftUI, QuillHighlight, QuillImageLoader). A fifth module, QuillCore, has no public API and is not a consumer-facing target.
Most integrations touch fewer than 10 of them.
The entry points are:

- **UIKit:** ``QuillView`` and four methods (``QuillView/append(_:)``, ``QuillView/finish()``, ``QuillView/reset()``, ``QuillView/cancelStreaming()``).
- **SwiftUI:** ``QuillStreamView`` for streaming and ``QuillMarkdownView`` for static content.
- **Configuration:** ``QuillConfiguration`` and its nested types (``QuillConfiguration/Streaming``, ``QuillConfiguration/Images``).
- **Theme:** ``QuillTheme`` with per-element token groups.
- **Streaming behavior:** ``QuillStreamingPreset`` with three named presets plus two custom variants.
- **Extension points:** ``SyntaxHighlighting`` and ``ImageLoading`` protocols.

The public surface was kept narrow for two reasons: to keep integration cost low, and to keep future refactoring of internals possible without breaking downstream code.

### Integration cost

A library's integration cost is roughly proportional to the number of concepts a developer must understand to use it.
Quill's public surface was shaped so that a typical integration requires understanding:

1. How to feed chunks in (one method or a SwiftUI binding).
2. How to signal completion.
3. How to theme the result (tokens in ``QuillTheme``).
4. Optionally, how to plug in syntax highlighting or image loading (two protocols).

That is a small mental model.
A developer can read <doc:GettingStarted>, integrate Quill, and ship in under an hour.
Each additional public concept would tax that path.

Libraries that expose rich configuration APIs often look good on paper (dozens of knobs to tune!) but make every integration a decision-heavy process.
Quill's defaults are chosen so that most apps can skip configuration entirely and revisit it only when a specific need arises.

### Refactoring space

Internal refactors -- replacing the parser, redesigning the pipeline, changing how tail reveal animates -- should not require a semver-major bump.
By keeping the public surface narrow, Quill preserves freedom to evolve its internals.
When users write `QuillView(configuration: ...)`, they bind to an API, not to an implementation.

This is why most types under `Sources/QuillKit/API/` are not truly public API.
Internal configurations (`RenderConfiguration`, `LayoutConfiguration`, `PerformanceProfile`, `TailRevealPolicy`, `BufferedStreamConfiguration`) live in `API/` by source-organization convention but are `internal` in Swift access control.
They can change freely between versions.

The small public surface is a commitment to downstream stability.
Consumers who integrate Quill should not need to track internal restructuring.

## Native rendering over web views

Quill renders via TextKit 2 -- Apple's native text rendering system.
No WebKit, no JavaScript, no HTML-in-WKWebView shim.

Web-view-based Markdown renderers exist and have legitimate use cases.
They inherit the entire CSS ecosystem, they support Markdown features Quill does not (like arbitrary HTML embedding), and they share a familiar toolchain across platforms.
Quill trades those benefits for native behavior that matters in iOS apps:

- **UIKit selection.**
  Text selection follows the standard iOS gestures -- long-press to select a word, drag handles to extend, tap the magnifying glass for cursor positioning.
  Copy goes through the system menu, respecting user's Universal Clipboard and Handoff.
  Web-view selection implements its own gesture layer that behaves subtly differently from the rest of the app.
- **VoiceOver.**
  Native text surfaces are navigable by VoiceOver with accurate reading order.
  Web views with dynamic content often produce incorrect or erratic VoiceOver behavior -- the browser's accessibility tree is not trivially compatible with iOS conventions, and dynamic content updates can reset focus unpredictably.
- **Dynamic Type.**
  Font sizes scale with the user's content size preference automatically when using native `UIFont` text styles.
  Web views must reimplement this via CSS media queries and user preference propagation -- often incompletely.
  Accessibility-scale text sizes (XL and XXL) particularly expose gaps in web-view Dynamic Type coverage.
- **Memory.**
  A WKWebView process carries hundreds of megabytes of browser overhead in addition to the rendered content.
  A ``QuillView`` carries the layout manager and text storage for its rendered content and nothing else.
  In AI chat UIs where multiple message views are on screen, the difference compounds.

These are not theoretical advantages.
They show up the moment a user tries to copy text to another app, uses VoiceOver to read a response, or sets accessibility-scaled text sizes.
Web-view-based renderers can reach parity on individual axes, but doing so typically requires substantial per-feature engineering.
Native rendering gets these behaviors by default.

### What Quill gives up

The native choice means Quill does not and cannot support:

- **Custom HTML embedding.** HTML in Markdown renders as escaped plain text, not as styled content.
- **CSS-based theming.** Visual styling uses Quill's token system (see <doc:CustomizingTheme>), not CSS.
- **Browser-based features.** Animations via CSS, font loading via `@font-face`, and similar browser-native patterns are not available.

For apps where these tradeoffs are wrong -- where web-based theming or HTML embedding is a hard requirement -- Quill is not the right choice.
See [Docs/CompetitiveResearch.md](https://github.com/krzyszt0xF/swift-quill/blob/main/Docs/CompetitiveResearch.md) for libraries that take the other side of this tradeoff.

## Scope boundaries for v1.0

Quill's v1.0 supports GitHub Flavored Markdown's block and inline syntax, streams incrementally, and provides reasonable defaults plus customization hooks for the most common integration points.
It does not support several things that Markdown renderers often do.
These exclusions are deliberate.

### No Markdown editing

Quill renders Markdown.
It does not accept Markdown editing -- no input focus, no text cursor, no syntax-highlighted source editing.

Markdown editing is a substantially different problem: bidirectional parsing between source and rendered forms, incremental reparsing of user edits, cursor stability across formatting changes, and undo/redo that operates on rendered content.
A single library that tries to cover both rendering and editing compromises on both.
Quill's use case is AI chat UIs rendering assistant responses.
Markdown editors are a different product and deserve a dedicated library.

### No LaTeX / math rendering

Mathematical notation via LaTeX or KaTeX syntax is not supported.

The reasoning is scope.
LaTeX rendering is itself a substantial engineering problem: parsing TeX, laying out complex symbols with correct spacing, handling inline vs display math, supporting the full symbol library developers expect.
The typical iOS implementation delegates to a JavaScript-based MathJax or KaTeX wrapper running in a web view.
That introduces WebKit as a dependency, which contradicts the native-rendering choice above.

For apps where math rendering matters, integrate a dedicated math-rendering library alongside Quill -- render non-math text with Quill, compose math blocks separately.
Plugging LaTeX into Quill itself would require either accepting the WebKit dependency or implementing native math rendering, which is out of scope for v1.0.

### No row-by-row table streaming

Tables render atomically once the closing row and trailing blank line arrive.
Partial tables do not reveal row-by-row during streaming.
This is discussed further in <doc:SupportedMarkdown>.

The short version: row-by-row rendering would either require rendering incomplete tables (layout quality suffers) or waiting for the next row indefinitely (the "last row" ambiguity).
Rendering the complete table atomically is the tradeoff that keeps visual quality high.

### No incremental code highlighting

Syntax highlighting applies after a code block's closing fence.
Mid-stream, code renders as unstyled text.
The alternative -- highlighting on every chunk -- produces incorrect tokenization (a string literal spanning chunks is tokenized as code until the closing quote arrives) and wastes significant CPU on content that will be reprocessed moments later.

The short phase of unstyled code during streaming is a tradeoff for correctness.

### No plugin system for custom blocks

Quill does not expose an API for registering custom block types (diagrams, charts, interactive widgets embedded in Markdown).
A plugin API is a large design surface: custom blocks need parse hooks, render hooks, layout integration, theme integration, accessibility integration, and selection integration.

Exposing those hooks publicly commits Quill to a stability contract that would constrain internal refactoring.
Changing how Quill measures heights, coalesces updates, or integrates with TextKit 2 would risk breaking third-party plugins, and the plugin surface would dominate semver decisions.

For apps that need embedded non-Markdown content (a chart widget, a code sandbox), render the Markdown with Quill and compose surrounding views in the host app.
This is not a workaround; it is often the cleaner architecture regardless.

### No support outside iOS

Quill targets iOS 17+.
No macOS, tvOS, watchOS, or visionOS support ships in v1.0.

Cross-platform support is feasible -- TextKit 2 is available on macOS, and several core types could be shared with minor platform gating.
It was scoped out to keep the initial release focused.
Supporting additional platforms would multiply testing surface, benchmarking effort, and the list of platform-specific UI behaviors Quill would need to track (different selection conventions on macOS, hover vs touch, window resize behavior).

Post-v1.0, platform expansion is open for discussion based on demand signals from adopters.

## Roadmap and evolution

Quill's v1.0 scope was drawn conservatively.
Features that did not make v1.0 are candidates for future versions based on evidence of demand: issue reports, use-case requests, contributor interest.
The goal is to evolve the library where it matters, not to accumulate features because they seem plausible.

The path from v1.x to v2.x (or later) depends on what turns out to matter in practice.
Some candidates that could plausibly appear in future versions:

- macOS support (TextKit 2 is available; scope is testing and platform-specific UI conventions).
- Additional streaming modes beyond the current presets.
- Extended theme customization (per-element animations, additional token groups).
- A plugin hook for custom block types, if a common pattern emerges across multiple integrations.
- Richer accessibility hooks beyond the defaults TextKit 2 and UIKit provide.

Features unlikely to be added in any version, because they contradict core design decisions:

- LaTeX/math rendering as a first-class feature (would compromise the native-rendering commitment).
- Markdown editing (different problem domain entirely).
- Web-view rendering backend (directly contradicts the native-rendering choice).

The [ROADMAP.md](https://github.com/krzyszt0xF/swift-quill/blob/main/ROADMAP.md) file in the repository tracks concrete near-term plans when they exist.

## See Also

- <doc:StreamingConcepts> -- the frozen prefix / active tail model in depth
- <doc:GettingStarted> -- practical integration after reading the why
- <doc:SupportedMarkdown> -- the full list of supported and unsupported elements
- <doc:CustomizingTheme> -- the token-based styling system
