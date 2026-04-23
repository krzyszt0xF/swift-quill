# ``SyntaxHighlighting``

Protocol for syntax-aware styling of fenced code blocks.

## Overview

``SyntaxHighlighting`` is the extension point for syntax highlighting. Conform to provide code block styling; Quill calls ``SyntaxHighlighting/highlight(code:language:)`` after a code block's closing fence arrives and applies the returned attributed string.

For a ready-to-use highlighter covering common languages, use `QuillHighlight.SyntaxHighlighter.default`. For custom highlighters (Tree-sitter bindings, custom backends), conform to ``SyntaxHighlighting`` directly.

See <doc:Integrations> for implementation recipes.

### Threading

``SyntaxHighlighting/highlight(code:language:)`` is called on a background queue after a code block's fence closes.
Conformers must be `Sendable` and implement thread-safe highlighting.
The returned `NSAttributedString` is applied on the main actor by Quill; conformers do not need to handle main-actor delivery themselves.
Return `nil` when highlighting cannot be produced synchronously; Quill keeps the plain code block rendering.

## Topics

### Required

- ``highlight(code:language:)``

## ``highlight(code:language:)``

Returns a syntax-highlighted attributed string for code, or `nil` to fall back to plain code block rendering.

- Parameter code: The code content between the fences (excluding the fence markers themselves).
- Parameter language: The language tag as written in the Markdown fence (for example, `swift`, `py`, `javascript`). May be empty.
- Returns: An `NSAttributedString` with syntax-aware attributes applied, or `nil` if the language is unrecognized or highlighting fails.

Returning `nil` causes Quill to render the code block as unstyled monospace text -- a graceful fallback that preserves readability.
