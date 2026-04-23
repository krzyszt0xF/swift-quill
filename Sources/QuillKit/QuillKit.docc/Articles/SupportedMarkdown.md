# Supported Markdown

Element-by-element coverage of Markdown features, streaming behavior, and the caveats that matter during integration.

@Metadata {
    @PageKind(article)
    @PageColor(gray)
}

## Overview

Quill implements GitHub Flavored Markdown (GFM), the same dialect GitHub uses for READMEs and issues.
The full feature list is in this article.

Every supported element streams incrementally in one of three modes:

- **Chunk-level** -- inline content and text-based block elements (paragraphs, headings, lists, blockquotes).
- **Block-close** -- elements whose rendering depends on a closing token (code blocks, tables, standalone images).
- **Immediate** -- single-line blocks that render as soon as the line arrives (thematic breaks).

For the mental model of what "streams incrementally" means and when blocks promote from the active tail to the frozen prefix, see <doc:StreamingConcepts>.
This article is the reference companion.

## Feature matrix

| Element | Support | Streaming mode | Notes |
|---------|---------|----------------|-------|
| Paragraphs | Full | Chunk-level | Text flows into the tail as chunks arrive; promotes on blank line. |
| Headings (H1--H6) | Full | Chunk-level | ATX-style only; promotes when the heading line ends. |
| Strong (`**bold**`) | Full | Chunk-level | Resolves when both `**` markers are present in the tail. |
| Emphasis (`*italic*`) | Full | Chunk-level | Resolves when both `*` markers are present. |
| Strikethrough (`~~text~~`) | Full | Chunk-level | GFM extension; resolves when both `~~` markers are present. |
| Inline code (`` `code` ``) | Full | Chunk-level | Resolves when both backticks are present. |
| Links (`[text](url)`) | Full | Chunk-level | Tappable via consumer callback; URL not validated by Quill. |
| Images (standalone) | Full | Block-close | Renders after the image URL parses; async loading via ``ImageLoading``. |
| Images (inline in list items) | Fallback | Chunk-level | Renders as alt-text fallback, not as a standalone image block. |
| Unordered lists | Full | Chunk-level | Items promote on blank line or non-list line; nested lists supported. |
| Ordered lists | Full | Chunk-level | Same as unordered; numbering preserved. |
| Task list items (`- [ ]`, `- [x]`) | Full | Chunk-level | GFM extension; rendered with checkbox and preserved task state. |
| Blockquotes | Full | Chunk-level | Bar-decorated; nested blockquotes supported. |
| Code blocks (fenced) | Full | Block-close | Plain text until fence close; syntax highlighting applies afterward if a highlighter is configured. |
| Tables (GFM) | Full | Block-close | Render after the closing row arrives; no row-by-row streaming; column alignment (left, center, right) supported. |
| Thematic breaks (`---`) | Full | Immediate | Single-line block; renders as soon as the line arrives. |
| Setext headings (`===`, `---` under text) | Not supported | -- | Use ATX-style headings (`#`, `##`, ...) instead. |
| HTML blocks (`<div>`, etc.) | Not supported | -- | HTML in Markdown renders as escaped plain text. |
| Math (LaTeX, KaTeX) | Not supported | -- | See <doc:DesignPhilosophy> for the v1.0 scope decision. |
| Footnotes | Not supported | -- | GFM extension not currently included. |

## Streaming modes explained

### Chunk-level

The element renders progressively as chunks arrive.
Partial content is visible in the active tail.
The element promotes to the frozen prefix when its terminator arrives.

Terminators vary by element:

- For paragraphs, a blank line.
- For list items, a blank line or a non-list line.
- For headings, the end of the heading line.

Inline formatting (bold, italic, links) resolves as soon as both delimiters are present in the same chunk or across consecutive chunks.

Chunk-level streaming is what makes Quill feel "live" during LLM output.
Users see text appear as it arrives, without waiting for paragraph boundaries.

### Block-close

The element only renders once its closing token arrives.
Until then, the raw Markdown text shows in the active tail.

Three elements use block-close streaming:

- **Code blocks** -- syntax highlighting applies after the closing fence; the code streams as plain unstyled text during the open phase.
- **Tables** -- the entire table renders only after the last row and its following blank line.
- **Standalone images** -- the image URL must fully parse before the async image load begins.

Block-close streaming trades some progressiveness for rendering correctness.
Highlighting a partial code block or rendering a half-parsed table would produce flicker or incorrect layout.

### Immediate

The element renders as soon as its single line arrives.
No terminator is needed because the element is defined by a single line.

Only thematic breaks use immediate streaming.
The line `---` (or `***`, or `___`) on its own line produces a horizontal rule in the document.

## Caveats and edge cases

### Inline images in lists render as fallback

Standalone image paragraphs render as image blocks with async loading, placeholder, and optional retry.
Image syntax inside a list item (`- ![alt](url)`) renders as alt-text fallback instead of a standalone image block.

This is a deliberate scope decision.
Mixed inline image syntax inside flowing content would require positioning logic that Quill's v1.0 architecture does not provide.

Workaround: render images as standalone block paragraphs outside of lists where possible.
If the LLM response is under your control, nudge the prompt to keep images on their own lines rather than inside list items.

### Tables render as one unit, not row-by-row

During streaming, the raw Markdown text of a partial table shows in the active tail.
Rendering happens atomically after the closing row arrives followed by a blank line.
A streaming LLM response that emits a long table shows as pipe-separated text until completion.
There is no row-by-row reveal.

This is a deliberate tradeoff.
Row-by-row streaming would require rendering partial tables (which looks broken) or waiting indefinitely for the next row (which breaks the "last row completes the table" semantic).
Rendering the complete table in one update keeps the visual result clean at the cost of a brief "raw Markdown" phase.

### Code highlighting applies after fence close

A fenced code block streams as unstyled text while the fence is open.
When the closing fence arrives, the block promotes and the syntax highlighter (if configured) processes the complete content and replaces the plain text with highlighted text in a single update.

This avoids two problems at once.
First, re-highlighting on every chunk would be expensive and wasteful because most chunks do not change highlighting decisions.
Second, highlighting incomplete code produces incorrect results -- a string literal spanning multiple chunks would tokenize as code until the closing quote arrives.

Users see plain text briefly before highlighting appears.
For typical LLM streaming speeds, this phase is under a second.

### Table cells copy as a single unit

When a user selects a table and copies it, Quill copies the table as an embedded unit, not per-cell.
The pasted content preserves the table structure for other Quill views or Markdown-aware apps.
For text-only paste targets, the pasted content is the underlying Markdown source of the table.

This matches the behavior developers expect from GitHub's rendered tables and other Markdown-aware text surfaces.

### Link URLs are not validated by Quill

Quill delivers the raw URL from the Markdown to your link tap handler.
URL schemes, hosts, and paths are your responsibility to validate.

Particularly for content from untrusted sources (LLM output, user-generated content), validate against `javascript:`, `data:`, and unexpected custom schemes before opening.

See the link-tap handler examples in <doc:GettingStarted> for the idiomatic pattern.

## GFM extensions in detail

Quill implements the following GFM extensions beyond CommonMark:

- **Strikethrough** (`~~text~~`) -- inline formatting.
- **Task lists** (`- [ ]`, `- [x]`) -- rendered as checkboxes with preserved task state.
- **Tables** -- pipe-separated rows with column alignment via the header separator syntax (`:---`, `:---:`, `---:` for left, center, right).
- **Autolinks** -- bare URLs in text render as tappable links when they match common URL patterns.

CommonMark-only features are not supported.
See the feature matrix for the full list of unsupported elements -- raw HTML blocks and footnotes are the most commonly encountered.

## See Also

- <doc:StreamingConcepts> -- how streaming and block promotion work
- <doc:CustomizingTheme> -- styling each element type
- <doc:Integrations> -- syntax highlighting and image loading for code blocks and images
- ``QuillTheme`` -- the theme type controlling per-element appearance
