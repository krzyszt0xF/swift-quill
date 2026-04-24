# ``QuillTheme``

Token-based visual theme for Markdown rendering.

## Overview

``QuillTheme`` bundles all visual styling as a value type. Token groups cover body text, headings, links, inline code, fenced code blocks, blockquotes, tables, lists, images, thematic breaks, and shared spacing. Each token group is a value type -- mutating one leaves the rest of the theme untouched.

For hands-on theme customization, see <doc:CustomizingTheme>. For individual token types and their properties, see ``QuillTheme/Body``, ``QuillTheme/Heading``, ``QuillTheme/CodeBlock``, and the other nested types listed below.

### Presets

Two presets ship with Quill:

- ``default`` -- neutral baseline, suitable as a starting point for apps without strong visual identity.
- ``github`` -- mirrors GitHub's rendered Markdown style; suitable for developer-audience apps (documentation viewers, coding assistants, IDE-adjacent tools).

Use a preset as-is, or copy and modify:

```swift
var theme = QuillTheme.github
theme.link.color = .systemBlue
```

Because ``QuillTheme`` is a value type, copies are cheap and mutations are local.

### Thread safety

``QuillTheme`` is `@unchecked Sendable`.
Treat theme instances as immutable snapshots after passing into ``QuillConfiguration`` -- mutating a theme after it has been consumed by a rendering view produces undefined behavior.

## Topics

### Presets

- ``default``
- ``github``

### Creating a theme

- ``init(blockquote:body:codeBlock:heading:image:inline:link:list:spacing:table:thematicBreak:)``
- ``init()``

### Token groups

- ``QuillTheme/Body``
- ``QuillTheme/Heading``
- ``QuillTheme/Link``
- ``QuillTheme/Inline``
- ``QuillTheme/CodeBlock``
- ``QuillTheme/Blockquote``
- ``QuillTheme/Table``
- ``QuillTheme/List``
- ``QuillTheme/Image``
- ``QuillTheme/ThematicBreak``
- ``QuillTheme/Spacing``

### Properties

- ``blockquote``
- ``body``
- ``codeBlock``
- ``heading``
- ``image``
- ``inline``
- ``link``
- ``list``
- ``spacing``
- ``table``
- ``thematicBreak``

## ``default``

The default theme: neutral baseline with system fonts and colors. Uses `.systemFont(ofSize: 16)` for body, heading weights descending from bold (H1, H2) to semibold (H3, H4) to medium (H5, H6), `.systemBlue` for links, and Menlo 14 for code blocks on a `systemBackground` surface.

Use as a starting point when your app has no strong visual brand, or as a base for gradual customization.

## ``github``

Theme mirroring GitHub's rendered Markdown style. Uses semibold heading weights across all six levels, GitHub-style link colors (dynamic light/dark via `UIColor` provider), Menlo 13 for code blocks on a dynamic light/dark surface, and Menlo for table fonts.

Suitable for apps targeting developer audiences where GitHub's visual conventions feel native -- documentation viewers, coding assistants, IDE-adjacent tools.

## ``init(blockquote:body:codeBlock:heading:image:inline:link:list:spacing:table:thematicBreak:)``

Creates a theme with explicit values for all token groups.

- Parameter blockquote: Token group for blockquote styling.
- Parameter body: Token group for body text.
- Parameter codeBlock: Token group for fenced code blocks.
- Parameter heading: Token group for headings H1-H6.
- Parameter image: Token group for image placeholders and decoration.
- Parameter inline: Token group for inline code (backticks).
- Parameter link: Token group for link styling.
- Parameter list: Token group for list markers and indentation.
- Parameter spacing: Shared spacing tokens between block elements.
- Parameter table: Token group for GFM tables.
- Parameter thematicBreak: Token group for horizontal rules.

All parameters are required. For customization, prefer copying a preset (``default`` or ``github``) and mutating specific properties rather than constructing from scratch.

## ``init()``

Creates a theme using the ``default`` preset.

Shorthand for `QuillTheme.default`. Provided for convenience; most integrations should use the named preset accessor directly.

## ``blockquote``

Token group controlling blockquote appearance. See ``QuillTheme/Blockquote``.

## ``body``

Token group controlling body (paragraph) text styling. See ``QuillTheme/Body``.

## ``codeBlock``

Token group controlling fenced code block appearance. See ``QuillTheme/CodeBlock``.

## ``heading``

Token group controlling heading styling for H1-H6. See ``QuillTheme/Heading``.

## ``image``

Token group controlling standalone image block rendering. See ``QuillTheme/Image``.

## ``inline``

Token group controlling inline code (backticked) styling. See ``QuillTheme/Inline``.

## ``link``

Token group controlling link styling. See ``QuillTheme/Link``.

## ``list``

Token group controlling list markers, bullets, and indentation. See ``QuillTheme/List``.

## ``spacing``

Shared spacing tokens applied between block elements. See ``QuillTheme/Spacing``.

## ``table``

Token group controlling GFM table rendering. See ``QuillTheme/Table``.

## ``thematicBreak``

Token group controlling horizontal rule rendering. See ``QuillTheme/ThematicBreak``.
