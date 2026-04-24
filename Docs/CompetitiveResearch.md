# Competitive Research -- Markdown Rendering Libraries for iOS

## Purpose and methodology

This document is the research foundation for deciding whether a "Quill vs. alternatives" comparison belongs in README.md. It also serves as a standalone record of due diligence -- every claim about a competitor is sourced and versioned so it can be re-verified.

**Verification methodology:** Each claim about a competitor is verified through actual source code inspection or official documentation, not blog posts or star counts. Every verified claim includes a source URL, version or commit inspected, and the date of inspection.

**Confidence levels:**

| Level | Meaning |
|-------|---------|
| Verified | Confirmed by reading source code or official documentation |
| Partial | Based on README/author statement that could not be confirmed in source, or feature exists with significant caveats |
| Cannot verify | Not enough evidence to make a claim |

**Safe-fail protocol:** If fewer than 3 feature rows can be fully verified across all libraries, the comparison table does NOT appear in README.md. Only verified claims are eligible for README inclusion.

**Date of research:** 2026-04-16. This document should be re-verified before any major README update.

## Libraries evaluated

### swift-markdown-ui

- **Repository:** https://github.com/gonzalezreal/swift-markdown-ui
- **Version inspected:** 2.4.1
- **Date inspected:** 2026-04-16
- **License:** MIT
- **GitHub stars at inspection:** ~3,800
- **Last commit to main:** 2025-12-28 (README update announcing maintenance mode)
- **Primary positioning:** SwiftUI library for rendering and customizing Markdown text, compatible with GFM spec.
- **Core rendering technology:** SwiftUI native `Text` concatenation with `AttributedString` for inline spans. Block layout via `VStack`/`Grid`. No TextKit, no WebKit.
- **Status:** Maintenance mode. Author is redirecting development to [Textual](https://github.com/gonzalezreal/textual) (v0.3.1, released 2026-01-25).

### Down

- **Repository:** https://github.com/johnxnguyen/Down
- **Version inspected:** v0.11.0 (tagged 2021-05-04)
- **Date inspected:** 2026-04-16
- **License:** MIT (primary); vendored cmark is BSD 2-Clause
- **GitHub stars at inspection:** ~2,500
- **Last commit to main:** 2021-10-18
- **Primary positioning:** Fast CommonMark parser/renderer wrapping the C cmark library, producing HTML, NSAttributedString, or WebView output.
- **Core rendering technology:** Dual-path: WKWebView (`DownView`) or TextKit 1 / NSAttributedString (`DownTextView`). Vendored cmark v0.29.0 (standard CommonMark, not GFM).
- **Status:** Effectively abandoned. Zero code commits since October 2021. 45 open issues, unmerged community PRs for Xcode 26 compatibility.

### MarkdownView

- **Repository:** https://github.com/keitaoouchi/MarkdownView
- **Version inspected:** 2.1.0 (released 2026-02-23)
- **Date inspected:** 2026-04-16
- **License:** MIT
- **GitHub stars at inspection:** ~2,100
- **Last commit to main:** 2026-03-06
- **Primary positioning:** General-purpose Markdown rendering via WKWebView with CSS theming.
- **Core rendering technology:** WKWebView wrapping markdown-it (JS) + highlight.js + Bootstrap CSS. All content rendered as HTML inside a web view.
- **Status:** Active. v2.0 rewrite in February 2026 added WKWebView pooling.

### MarkdownDisplayView

- **Repository:** https://github.com/zjc19891106/MarkdownDisplayView
- **Version inspected:** 1.7.4 (released 2026-04-10)
- **Date inspected:** 2026-04-16
- **License:** Apache-2.0
- **GitHub stars at inspection:** ~160
- **Last commit to main:** 2026-04-10
- **Primary positioning:** TextKit 2 streaming Markdown renderer targeting AI chat applications. Repo topics include `ai-chat`, `gpt-streaming`, `claude-streaming`.
- **Core rendering technology:** Native TextKit 2 (`NSTextLayoutManager` + `NSTextContentStorage`) via custom `UIView`. Tables, code blocks, images, and LaTeX embedded as `NSTextAttachment`. Parser uses Apple's swift-markdown.
- **Status:** Very active. 4 releases in April 2026 alone. Solo maintainer (zjc19891106, 91 commits).

### Apple native Markdown primitives

- **Version inspected:** iOS 26.4 SDK
- **Date inspected:** 2026-04-16
- **License:** Apple SDK (proprietary)
- **Primary positioning:** Built-in Markdown support in Foundation and SwiftUI, based on cmark-gfm.
- **Core rendering technology:** `AttributedString(markdown:)` parses via cmark-gfm. SwiftUI `Text` renders inline spans only. No built-in block-level rendering.

## Feature matrix

Each cell uses the format: `Status: finding [source]`. Footnotes provide detailed source references.

### Streaming-first rendering

| Library | Status | Finding |
|---------|--------|---------|
| swift-markdown-ui | Verified: No | `Markdown` view accepts complete `String` or `MarkdownContent`. No append/reset/finish API. Zero results for `AsyncSequence`/`AsyncStream` in codebase. [^smu-1] |
| Down | Verified: No | `Down` is an immutable struct initialized with a complete `markdownString`. `DownView.update()` re-renders entirely. No incremental API. [^down-1] |
| MarkdownView | Verified: No | `render(markdown:)` is all-or-nothing. No streaming, append, or incremental API. [^mv-1] |
| MarkdownDisplayView | Verified: Yes | Two modes: simulated streaming (`startStreaming(_:unit:unitsPerChunk:interval:)` — typewriter playback of complete content) and real streaming (`beginRealStreaming(autoScrollBottom:onComplete:)` / `appendBlock(_:)` / `endRealStreaming(completion:)` — accepts unpredictable chunks from async sources). `MarkdownStreamBuffer` buffers incomplete structures and flushes complete modules. [^mdv-1] |
| Apple native | Verified: No | `AttributedString(markdown:)` is a one-shot parser. No incremental parsing, no append-chunk API. [^apple-1] |

### Rendering substrate

| Library | Status | Finding |
|---------|--------|---------|
| swift-markdown-ui | Verified | SwiftUI `Text` concatenation via `+` operator. `AttributedString` for inline spans. `VStack`/`Grid` for block layout. [^smu-2] |
| Down | Verified | Dual-path: WKWebView (`DownView`) or TextKit 1 with `NSLayoutManager` (`DownTextView`). No TextKit 2. [^down-2] |
| MarkdownView | Verified | WKWebView + markdown-it (JS). All content is HTML. [^mv-2] |
| MarkdownDisplayView | Verified | TextKit 2: `NSTextContentStorage` + `NSTextLayoutManager` + `NSTextContainer` in a custom `UIView`. [^mdv-2] |
| Apple native | Verified | `AttributedString` with `PresentationIntent` for block tagging. SwiftUI `Text` renders inline spans only; no native block-level renderer. [^apple-2] |

### Native text selection

| Library | Status | Finding |
|---------|--------|---------|
| swift-markdown-ui | Verified: Partial | Works via SwiftUI `.textSelection(.enabled)` modifier. Selection is per-`Text` view, not continuous across block boundaries. [^smu-3] |
| Down | Verified: Yes | Inherited from `UITextView` (TextKit 1 path) and `WKWebView` (WebKit path). No custom selection logic. [^down-3] |
| MarkdownView | Verified: Partial | Web-based selection only, inherited from WKWebView. Not native iOS selection. [^mv-3] |
| MarkdownDisplayView | Verified: No | Inherits from `UIView`, not `UITextView`. Only `UITapGestureRecognizer` for links. No selection handles, no copy. [^mdv-3] |
| Apple native | Verified: Yes | SwiftUI `Text` supports `.textSelection(.enabled)`. `UITextView` provides full native selection. [^apple-3] |

### GFM tables

| Library | Status | Finding |
|---------|--------|---------|
| swift-markdown-ui | Verified: Yes | `TableView.swift` uses SwiftUI `Grid`. Requires iOS 16+. [^smu-4] |
| Down | Verified: No | Vendored cmark v0.29.0 is standard CommonMark without GFM extensions. No table AST nodes. Open issues #299, #308, #309 confirm. [^down-4] |
| MarkdownView | Verified: Yes | Via markdown-it which supports GFM tables, rendered as HTML tables in WKWebView. [^mv-4] |
| MarkdownDisplayView | Verified: Yes | Column alignment, alternate row backgrounds, header styling, horizontal scroll. `UICollectionView` inside `NSTextAttachment`. Auto-fix for malformed streaming tables. [^mdv-4] |
| Apple native | Verified: Partial | `AttributedString(markdown:)` parses tables into `PresentationIntent` (.table, .tableHeaderRow, .tableRow, .tableCell). But no Apple view renders them. [^apple-4] |

### Code block syntax highlighting

| Library | Status | Finding |
|---------|--------|---------|
| swift-markdown-ui | Verified: Pluggable only | `CodeSyntaxHighlighter` protocol. Default is plain text. User must supply implementation. [^smu-5] |
| Down | Verified: No | `Styler` receives `fenceInfo` but default `DownStyler` applies only generic background. No token-level highlighting. [^down-5] |
| MarkdownView | Verified: Yes | Via bundled highlight.js (BSD-3-Clause). Automatic language detection. [^mv-5] |
| MarkdownDisplayView | Verified: Yes | Regex-based token highlighting for 20+ languages. Customizable colors with Xcode presets. [^mdv-5] |
| Apple native | Verified: No | `PresentationIntent.codeBlock(languageHint:)` captures the language string but no highlighting is applied. [^apple-5] |

### Image rendering

| Library | Status | Finding |
|---------|--------|---------|
| swift-markdown-ui | Verified: Yes | Async loading via `NetworkImage` dependency. Extensible via `ImageProvider` protocol. Asset-based images also supported. [^smu-6] |
| Down | Verified: Partial | WebKit path renders `<img>` tags. NSAttributedString path passes URL to `Styler` but does not load images by default. [^down-6] |
| MarkdownView | Partial: Likely yes | WKWebView renders `<img>` tags natively. No explicit image API found in source. [^mv-6] |
| MarkdownDisplayView | Verified: Yes | Async loading with `ImageCacheManager`. Lazy loading, placeholder display, configurable max height, tap callback. [^mdv-6] |
| Apple native | Verified: No | `![alt](url)` syntax is not rendered by SwiftUI `Text` or any native view. [^apple-6] |

### Custom themes

| Library | Status | Finding |
|---------|--------|---------|
| swift-markdown-ui | Verified: Yes | `Theme` struct with builder-pattern API. Per-element control for all block and inline styles. Built-in `basic` and `gitHub` themes. [^smu-7] |
| Down | Verified: Yes | CSS for WebKit path. `Styler` protocol + `DownStylerConfiguration` (font/color/paragraph collections) for NSAttributedString path. [^down-7] |
| MarkdownView | Verified: Yes | CSS injection, dark mode via `prefers-color-scheme`, Bootstrap defaults. `styled: false` for blank canvas. [^mv-7] |
| MarkdownDisplayView | Verified: Yes | Per-element font and color control. Preset `.default` and `.dark` configurations. Syntax highlight color presets. [^mdv-7] |
| Apple native | Verified: No | No theming API for Markdown. Standard SwiftUI/UIKit styling applies to the rendering view, not the Markdown content. [^apple-7] |

### Dynamic Type support

| Library | Status | Finding |
|---------|--------|---------|
| swift-markdown-ui | Verified: Yes | Uses `@ScaledMetric` for font scaling. PR #314 fixed double-scaling bug, confirming intentional support. [^smu-8] |
| Down | Verified: No | `StaticFontCollection` uses fixed sizes. No `UIFontMetrics` or `preferredFont(forTextStyle:)` in styling system. [^down-8] |
| MarkdownView | Verified: No | WKWebView does not participate in iOS Dynamic Type. [^mv-8] |
| MarkdownDisplayView | Verified: No | Uses fixed `UIFont` sizes. No Dynamic Type wrapper or `UIContentSizeCategoryAdjusting` conformance. [^mdv-8] |
| Apple native | Verified: Yes | SwiftUI `Text` with system fonts respects Dynamic Type automatically. [^apple-8] |

### Swift 6 strict concurrency

| Library | Status | Finding |
|---------|--------|---------|
| swift-markdown-ui | Verified: Partial | `Theme` and `InlineNode` are `Sendable`. Package uses swift-tools-version 5.6. No broader adoption. [^smu-9] |
| Down | Verified: No | swift-tools-version 5.3, Swift language version 5. No `Sendable`, no `async`/`await`, no actors. [^down-9] |
| MarkdownView | Verified: No | swift-tools-version 6.0 but `.swiftLanguageMode(.v5)` on target. No concurrency annotations. [^mv-9] |
| MarkdownDisplayView | Verified: No | swift-tools-version 5.9. `NSLock` for parser serialization, manual `Thread.isMainThread` checks. No actors. [^mdv-9] |
| Apple native | N/A | Apple frameworks. `AttributedString` is `Sendable`. |

### Minimum iOS version

| Library | Version | Source |
|---------|---------|--------|
| swift-markdown-ui | iOS 15 (tables require iOS 16) | Package.swift [^smu-10] |
| Down | iOS 9 | Package.swift, Down.podspec [^down-10] |
| MarkdownView | iOS 16 | Package.swift [^mv-10] |
| MarkdownDisplayView | iOS 15 | Package.swift [^mdv-10] |
| Apple native | iOS 15 | SDK availability |

### Dependencies

| Library | External dependencies | Source |
|---------|----------------------|--------|
| swift-markdown-ui | swift-cmark (swiftlang), NetworkImage (gonzalezreal), swift-snapshot-testing (test only) | Package.swift [^smu-11] |
| Down | None. Vendored cmark v0.29.0 as C source. | Package.swift [^down-11] |
| MarkdownView | None. Bundles markdown-it, highlight.js, Bootstrap as JS/CSS resources. | Package.swift [^mv-11] |
| MarkdownDisplayView | swift-markdown (Apple) | Package.swift [^mdv-11] |
| Apple native | N/A | Built into SDK |

## Per-library deep analysis

### swift-markdown-ui

**What it does well:** Rich SwiftUI-native theming system with per-element control. The builder-pattern `Theme` API is well designed. GFM support is solid including tables (iOS 16+). The library is the most feature-complete pure-SwiftUI Markdown renderer available.

**What Quill does differently:** Quill renders through a UIKit/TextKit pipeline, not SwiftUI `Text` concatenation. Quill is streaming-first with frozen-prefix/active-tail architecture. Quill provides native text selection across the full document, not per-block.

**When to choose swift-markdown-ui over Quill:** When your app is pure SwiftUI with no UIKit, when content is static (not streaming), and when you need the richest SwiftUI theming DSL available. Also when targeting iOS 15 without UIKit dependency.

**Open questions:** Textual (the successor) may add features that change this analysis. Textual v0.3.1 adds native selection, math rendering, and built-in syntax highlighting but does not appear to support streaming as of 2026-01-25.

### Down

**What it does well:** Zero external dependencies. The vendored cmark C library is fast and battle-tested. The `Styler` protocol provides deep customization of NSAttributedString output. iOS 9+ support means maximum device compatibility.

**What Quill does differently:** Quill uses TextKit 2 (not TextKit 1). Quill supports GFM (tables, strikethrough, task lists). Quill has a streaming pipeline. Quill uses Swift 6 concurrency.

**When to choose Down over Quill:** When you need to support iOS versions older than iOS 17. When you want zero dependencies and a simple CommonMark-to-NSAttributedString pipeline without streaming. When WebKit-based rendering with CSS theming is preferred.

**Verified technical claims:** Down is unmaintained since October 2021. Its vendored cmark is standard CommonMark v0.29.0, not GFM -- confirmed by absence of `table.c` and `strikethrough.c` in `Sources/cmark/`. This means no tables, no strikethrough, no task lists.

### MarkdownView

**What it does well:** CSS-based theming gives maximum visual flexibility. Bundled highlight.js provides syntax highlighting for many languages out of the box. The v2.0 rewrite (February 2026) added WKWebView pooling for better list performance.

**What Quill does differently:** Quill renders natively through TextKit, not via a web view. Quill supports streaming. Quill supports Dynamic Type. Quill provides native iOS text selection.

**When to choose MarkdownView over Quill:** When you want web-standard CSS theming. When you need highlight.js language coverage (broader than most native highlighters). When content is static and the web view performance overhead is acceptable.

**Open questions:** Image rendering is likely supported via WKWebView's native `<img>` handling, but no explicit image API was found in the source code.

### MarkdownDisplayView

**What it does well:** Closest competitor to Quill in the streaming space. Has two distinct streaming modes: simulated typewriter playback and real AI streaming via `beginRealStreaming`/`appendBlock`/`endRealStreaming`. The `MarkdownStreamBuffer` (401 lines) detects complete Markdown modules (heading boundaries, code fence counting, table boundary detection) and buffers incomplete structures. Active development with frequent releases. GFM tables with auto-fix for malformed streaming output. Built-in regex syntax highlighting for 20+ languages. LaTeX support via KaTeX.

**What Quill does differently:** Quill uses a separated module architecture (QuillCore/QuillKit/QuillSwiftUI) vs. multi-file but single-target layout (~4,000 lines across 17 source files). Quill provides native text selection (UITextView-based). Quill has a SwiftUI wrapper. Quill uses Swift 6 strict concurrency with actors and `@MainActor` vs. `NSLock` and manual thread checks. Quill's streaming uses a frozen-prefix/active-tail pipeline with explicit coalescing vs. heading-boundary module detection.

**When to choose MarkdownDisplayView over Quill:** When you need LaTeX/math rendering (Quill has no LaTeX in v1.0). When you need regex-based built-in syntax highlighting without an external dependency. When text selection is not required. When you prefer a single-view TextKit 2 architecture over a stack-of-views approach.

**Quill's disadvantages vs. MarkdownDisplayView:**

- No LaTeX rendering in v1.0.
- No built-in syntax highlighting (pluggable only via `QuillHighlight`).
- No auto-fix for malformed streaming tables.
- Higher star count does not apply -- MarkdownDisplayView has ~160 stars vs. Quill pre-release.

### Apple native primitives

See dedicated section below.

## Apple's native Markdown primitives

Apple introduced native Markdown in iOS 15 / macOS 12 (2021). The parser is cmark-gfm, but the rendering layer exposes only inline spans.

### `Text("**bold**")` -- SwiftUI inline Markdown

Works via `LocalizedStringKey` conformance to `ExpressibleByStringLiteral`. Supports bold, italic, strikethrough, inline code, and links. Does NOT support headings, lists, code blocks, blockquotes, tables, or images.

**Critical gotcha:** Only works with string literals, not `String` variables. `let md = "**bold**"; Text(md)` does NOT parse Markdown. Workaround: `Text(AttributedString(markdown: md))`.

### `AttributedString(markdown:)` -- Foundation parser

Parses full GFM Markdown into `PresentationIntent` attributes. Recognizes headings, lists, code blocks, blockquotes, tables, and thematic breaks at the structural level. However, no Apple view renders these block structures automatically. SwiftUI `Text` ignores `PresentationIntent` entirely. UITextView requires manual mapping from `PresentationIntent` to paragraph styles.

Projects like Markdownosaur (by the Apollo developer) exist specifically to bridge this gap.

**Not parsed:** Task list checkboxes (`- [ ]`, `- [x]`) despite using cmark-gfm.

### `TextEditor` + `AttributedString` (iOS 26)

iOS 26 added `AttributedString` binding support to `TextEditor`. This is a rich text editor improvement, not a Markdown renderer. It does not render headings, lists, code blocks, or tables.

### Streaming support

None. `AttributedString(markdown:)` is a one-shot parser. No incremental parsing, no append-chunk API. For LLM-style streaming, you must either re-parse the entire accumulated string on every chunk (O(n^2)) or build your own incremental parser.

### When native is enough

- Inline formatting in labels, buttons, settings descriptions, onboarding text.
- Localized strings with bold/italic/links via `.strings` files.
- Simple chat bubbles with basic formatting (no code blocks, tables, or images).

### When you need a library

- Block-level content: headings, lists, code blocks, blockquotes, tables.
- Syntax-highlighted code blocks.
- Images.
- Streaming Markdown (LLM responses).
- Task lists / checkboxes.
- Custom theming of block elements.

## Verdict: is a README comparison table justified?

### Verification count

Across the 11 feature columns, verification status for all 5 targets:

| Feature | All verified? |
|---------|---------------|
| Streaming | Yes -- all 5 verified |
| Rendering substrate | Yes -- all 5 verified |
| Native selection | Yes -- all 5 verified (some partial, but status confirmed) |
| GFM tables | Yes -- all 5 verified |
| Code highlighting | Yes -- all 5 verified |
| Image rendering | 4 verified, 1 partial (MarkdownView: likely but not confirmed in source) |
| Custom themes | Yes -- all 5 verified |
| Dynamic Type | Yes -- all 5 verified |
| Swift 6 concurrency | Yes -- all 5 verified |
| Min iOS version | Yes -- all 5 verified |
| Dependencies | Yes -- all 5 verified |

**Fully verified rows: 10 out of 11.** The image rendering row has one partial entry (MarkdownView).

### Recommendation: Include comparison table in README

The safe-fail threshold of 3 fully verified rows is exceeded. A comparison table in README is justified.

**Columns recommended for README (compact format):**

1. Streaming -- Quill's primary differentiator. Clearly verified across all targets.
2. Rendering substrate -- factual, no value judgment needed.
3. Native selection -- Quill advantage over MarkdownDisplayView (closest competitor).
4. GFM tables -- Quill advantage over Down and Apple native.
5. Code highlighting -- fair comparison; MarkdownView and MarkdownDisplayView have built-in, Quill is pluggable.

**Columns to omit from README** (include here only):
- Dynamic Type, Swift 6, min iOS, dependencies, custom themes -- too detailed for README. Belong in this research doc or DocC.

**Positioning note:** The README comparison should emphasize Quill's streaming architecture as the primary differentiator, not claim superiority across all dimensions. MarkdownDisplayView is a legitimate streaming competitor with features Quill lacks (LaTeX, built-in highlighting). swift-markdown-ui has a richer theming DSL. Honesty strengthens credibility.

### Decision update (2026-04-16): hybrid approach adopted

After initial research recommended including a full 5-column x 6-library comparison table in README, we reversed that decision in favor of a hybrid approach:

- **README.md** contains a short "How Quill compares" section with 3 named alternatives (swift-markdown-ui, MarkdownView, Apple native) for readers whose use case is different from Quill's streaming focus. No full comparison table.
- **This document (CompetitiveResearch.md)** remains the comprehensive source of truth with all 5 libraries, all 11 feature columns, and full source references.

Reasons for the change:

1. README comparison tables risk advertising direct competitors that most readers haven't encountered, diluting Quill's positioning for no real information gain -- most readers comparing Markdown libraries already know about swift-markdown-ui.
2. MarkdownDisplayView (~160 GitHub stars) is the closest architectural competitor but is not yet widely known. Putting it in README actively surfaces it to readers who might otherwise evaluate Quill in isolation.
3. Top iOS OSS libraries (Nuke, swift-composable-architecture) tend to keep competitor analysis in docs or FAQ rather than README, for the same reason.
4. Full research remains accessible for sceptical readers, HN commenters, or ecosystem participants who want the complete picture. Nothing is hidden -- just re-prioritized between marketing layer (README) and reference layer (this document).

This decision is reversible. If future feedback suggests the README's positioning is insufficient or that readers genuinely need a full comparison at first glance, the table can be restored to README from this document.

## Update log

| Date | Researcher | Libraries updated | Notes |
|------|------------|-------------------|-------|
| 2026-04-16 | Claude (agent-assisted) | All 5 | Initial research. Source inspection via GitHub API and web fetch. |

## Source references

[^smu-1]: `Sources/MarkdownUI/Views/Markdown.swift` -- 3 initializers, all accept complete content. GitHub code search: 0 results for AsyncSequence/AsyncStream.
[^smu-2]: `Sources/MarkdownUI/Renderer/TextInlineRenderer.swift`, `AttributedStringInlineRenderer.swift`, `Views/Blocks/TableView.swift`.
[^smu-3]: `Examples/Demo/Demo/DemoView.swift` -- uses `.textSelection(.enabled)`.
[^smu-4]: `Sources/MarkdownUI/Views/Blocks/TableView.swift` -- SwiftUI `Grid`.
[^smu-5]: `Sources/MarkdownUI/Extensibility/CodeSyntaxHighlighter.swift` -- protocol with `PlainTextCodeSyntaxHighlighter` default.
[^smu-6]: `Sources/MarkdownUI/Extensibility/DefaultImageProvider.swift` -- `NetworkImage(url:)`.
[^smu-7]: `Sources/MarkdownUI/Theme/Theme.swift` -- builder-pattern API with built-in `basic` and `gitHub` themes.
[^smu-8]: `Sources/MarkdownUI/Views/Markdown.swift` -- `@ScaledMetric` usage. PR #314 fixed double-scaling.
[^smu-9]: PR #351 (merged 2024-10-15) -- `Theme` conforms to `Sendable`. Package.swift: swift-tools-version 5.6.
[^smu-10]: Package.swift: `.iOS(.v15)`.
[^smu-11]: Package.swift: swift-cmark, NetworkImage, swift-snapshot-testing (test only).

[^down-1]: `Sources/Down/Down.swift` -- immutable struct. `Sources/Down/Views/DownView.swift` -- `update()` re-renders entirely.
[^down-2]: `Sources/Down/Views/DownView.swift` (WKWebView), `Sources/Down/AST/Styling/Text Views/DownTextView.swift` (TextKit 1), `Sources/Down/AST/Styling/Layout Managers/DownLayoutManager.swift` (NSLayoutManager).
[^down-3]: Class hierarchies in `DownView.swift` (WKWebView selection) and `DownTextView.swift` (UITextView selection).
[^down-4]: `Sources/cmark/` -- no table.c or strikethrough.c. AST nodes list has no Table type. GitHub issues #299, #308, #309.
[^down-5]: `Sources/Down/AST/Visitors/AttributedStringVisitor.swift`, `Sources/Down/AST/Styling/Stylers/DownStyler.swift` -- generic background only.
[^down-6]: `Sources/Down/AST/Visitors/AttributedStringVisitor.swift` -- `visit(image:)` exists but no default image loading.
[^down-7]: `Sources/Down/AST/Styling/Stylers/DownStylerConfiguration.swift` -- font/color/paragraph collections. `DownView.swift` -- CSS template.
[^down-8]: `Sources/Down/AST/Styling/Stylers/DownStylerConfiguration.swift` -- `StaticFontCollection` default.
[^down-9]: Package.swift: swift-tools-version 5.3, swiftLanguageVersions: [.v5].
[^down-10]: Package.swift: `.iOS(.v9)`. Down.podspec: iOS 9.0.
[^down-11]: Package.swift: single internal `libcmark` target. Zero external dependencies.

[^mv-1]: `MarkdownView.swift` -- `render(markdown:options:)` is the only content method.
[^mv-2]: Package.swift bundles HTML/JS resources. `MarkdownView.swift` uses `WKWebView` and `WKNavigationDelegate`.
[^mv-3]: WKWebView provides web-style selection by default.
[^mv-4]: markdown-it supports GFM tables, rendered as HTML `<table>` in WKWebView.
[^mv-5]: README lists highlight.js. `styled.html` includes highlight.js themes.
[^mv-6]: No explicit image API found. WKWebView renders `<img>` tags natively.
[^mv-7]: README documents CSS injection and `reconfigure(css:plugins:stylesheets:styled:)`.
[^mv-8]: WKWebView does not participate in iOS Dynamic Type.
[^mv-9]: Package.swift: swift-tools-version 6.0, `.swiftLanguageMode(.v5)` on target.
[^mv-10]: Package.swift: `.iOS(.v16)`.
[^mv-11]: Package.swift: no dependencies. JS/CSS bundled as resources.

[^mdv-1]: `ScrollableMarkdownViewTextKit.swift` lines 110-144 -- two modes: `startStreaming(_:unit:unitsPerChunk:interval:)` (typewriter) and `beginRealStreaming(autoScrollBottom:onComplete:)` / `appendBlock(_:)` / `endRealStreaming(completion:)` (real AI streaming). `MarkdownStreamBuffer.swift` (401 lines) -- `detectCompleteModules()`, `detectPendingStructure()`.
[^mdv-2]: `MarkdownTextViewTK2.swift` -- `UIView` with `NSTextContentStorage`, `NSTextLayoutManager`, `NSTextContainer`.
[^mdv-3]: `MarkdownTextViewTK2.swift` -- only `UITapGestureRecognizer`. No `UITextInteraction`.
[^mdv-4]: `MarkdownTableSupport.swift` -- UICollectionView in NSTextAttachment. CHANGELOG v1.7.0.
[^mdv-5]: `MarkdownParser.swift` -- `applySyntaxHighlighting(to:language:)`. README lists 20+ languages.
[^mdv-6]: `ImageCacheManager.swift`, `ImageLoader.swift`, `MarkdownImageAttachment.swift`.
[^mdv-7]: `MarkdownConfiguration` struct. README documents per-element font/color control.
[^mdv-8]: Fixed `UIFont` sizes. No Dynamic Type wrapper.
[^mdv-9]: Package.swift: swift-tools-version 5.9. `MarkdownParser.swift`: `NSLock`.
[^mdv-10]: Package.swift: `.iOS(.v15)`.
[^mdv-11]: Package.swift: swift-markdown (Apple) from 0.7.3.

[^apple-1]: `AttributedString(markdown:)` is one-shot. No incremental API in Foundation.
[^apple-2]: `PresentationIntent` enum cases document block-level tagging. SwiftUI `Text` ignores `PresentationIntent`.
[^apple-3]: SwiftUI `.textSelection(.enabled)` modifier. UITextView provides native selection.
[^apple-4]: `PresentationIntent.Kind` includes `.table`, `.tableHeaderRow`, `.tableRow`, `.tableCell`. No Apple view renders them.
[^apple-5]: `PresentationIntent.codeBlock(languageHint:)` captures language. No highlighting applied.
[^apple-6]: `![alt](url)` not rendered by SwiftUI `Text`.
[^apple-7]: No Markdown-specific theming API in SwiftUI or UIKit.
[^apple-8]: SwiftUI `Text` with system fonts respects Dynamic Type automatically.
