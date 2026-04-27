# Customizing Theme

Token-based styling for body text, headings, links, code, blockquotes, tables, and lists -- with dark mode support via `UIColor` dynamic providers.

@Metadata {
    @PageKind(article)
    @PageColor(orange)
}

## Overview

Quill's theme system is a value type (``QuillTheme``) composed of per-element tokens -- one token group for body text, one for headings, one for links, one for inline code, one for code blocks, and so on.
Modifying a theme is a matter of copying a preset and replacing specific tokens with your values.

Two presets ship with Quill: ``QuillTheme/default`` (neutral baseline) and ``QuillTheme/github`` (matches GitHub's rendered Markdown).
Either can serve as a starting point.
Color tokens can use `UIColor` dynamic provider closures for light/dark variants, so dark mode requires no additional work when you adopt the pattern.

## Token anatomy

Each element in a theme has a token group covering font, color, spacing, and element-specific properties.
A token group is intentionally narrow -- it describes how one element looks, not how multiple elements relate.

A typical token group contains:

- **Font** -- the `UIFont` to use for this element.
- **Text color** -- the foreground color. Use `UIColor` dynamic provider closures for light/dark variants.
- **Background color** (for block and inline-code elements) -- code blocks and inline code have backgrounds.
- **Spacing** -- vertical margins, expressed as a ``SpacingValue`` (absolute points or ``SpacingValue/relative(_:)``).
- **Element-specific properties** -- code block padding and border, blockquote bar width and color, table cell padding and separators, list marker characters.

Not every group contains every property.
Body has just font and text color; code block has eleven properties covering the code pane, header, copy button, and border.

## Built-in presets

### default

The neutral baseline.
Body text uses `.systemFont(ofSize: 16)`; heading font weights descend from bold (H1, H2) to semibold (H3, H4) to medium (H5, H6), scaled via `heading.fontScales` relative multipliers.
Link color is `.systemBlue` with single-underline.
Code blocks use Menlo 14 (falling back to `.monospacedSystemFont`) on a `systemBackground` surface.

Use the default preset when your app has no strong visual brand, or as a starting point before overriding specific tokens.

### github

Mirrors GitHub's rendered Markdown style.
All six heading levels use `.semibold` weight; link color uses a `UIColor` dynamic provider that adapts between a light-mode blue and a dark-mode brighter blue.
Code blocks use Menlo 13 on a dynamic light/dark surface (near-white in light mode, near-black in dark mode).
Table body and header fonts also use Menlo.

Use the GitHub preset when your app targets a developer audience (documentation viewers, coding assistants, IDE-adjacent tools) where GitHub's visual conventions feel native.

## Customizing a preset

``QuillTheme`` is a value type.
Copy a preset, modify specific tokens, and pass the result into ``QuillConfiguration``.

```swift
import QuillKit

var theme = QuillTheme.github
theme.body.font = .preferredFont(forTextStyle: .body)
theme.link.color = .systemBlue

let configuration = QuillConfiguration(
    streaming: .init(preset: .balanced),
    theme: theme
)
```

The copy is cheap -- token groups are value types, so replacing one leaves the rest of the theme untouched.
Pass the configured ``QuillTheme`` to ``QuillStreamView`` or ``QuillView`` via ``QuillConfiguration``.

### Changing body text

Body tokens control the base font and text color used for paragraphs:

```swift
var theme = QuillTheme.default
theme.body.font = .preferredFont(forTextStyle: .body)
theme.body.textColor = .label
```

For Dynamic Type support, replace the preset's fixed-size body font with a text-style-based font as shown above.
Text-style-based fonts scale with the user's accessibility preferences; fixed-size fonts do not.

### Changing heading styling

Headings in Quill share a single token group with two arrays keyed by level (H1 through H6):

```swift
theme.heading.fontScales = [
    .relative(2.0),   // H1
    .relative(1.6),   // H2
    .relative(1.3),   // H3
    .relative(1.15),  // H4
    .relative(1.05),  // H5
    .relative(1.0)    // H6
]
theme.heading.fontWeights = [
    .bold, .bold, .semibold, .semibold, .medium, .medium
]
theme.heading.spacingBefore = .relative(0.75)
```

`fontScales` is a ``SpacingValue`` array; `.relative(n)` multiplies the body font size, while absolute values are also supported.
`fontWeights` is one `UIFont.Weight` per level.
Arrays shorter than 6 elements reuse the last entry for higher levels.

### Changing link styling

Links have a single color and an underline style:

```swift
theme.link.color = .systemBlue
theme.link.underlineStyle = .single
```

WCAG guidance recommends links be distinguishable from body text by more than color alone.
Keep `underlineStyle` set to `.single` (or another visible style) unless your design system provides a different affordance.

For dark mode support, wrap the color in a dynamic provider:

```swift
theme.link.color = UIColor { traits in
    traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.34, green: 0.61, blue: 0.98, alpha: 1)
        : UIColor(red: 0.02, green: 0.40, blue: 0.85, alpha: 1)
}
```

### Changing code block appearance

Code blocks have the richest token group -- font, colors, padding, border, corner radius, and the copy button tint all live in ``QuillTheme/CodeBlock``:

```swift
theme.codeBlock.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
theme.codeBlock.textColor = .label
theme.codeBlock.backgroundColor = UIColor { traits in
    traits.userInterfaceStyle == .dark
        ? UIColor(white: 0.12, alpha: 1)
        : UIColor(white: 0.97, alpha: 1)
}
theme.codeBlock.cornerRadius = 8
theme.codeBlock.padding = 12
theme.codeBlock.copyButtonTint = .secondaryLabel
theme.codeBlock.languageLabelColor = .secondaryLabel
```

See <doc:Integrations> for pairing code block appearance with syntax highlighting from `QuillHighlight`.

### Changing inline code styling

Inline code (backticks inside paragraphs) uses a separate token group from fenced code blocks:

```swift
theme.inline.backgroundColor = .systemGray6
theme.inline.textColor = .label
theme.inline.fontSizeOffset = -1
```

`fontSizeOffset` is added to the body font size -- `-1` renders inline code slightly smaller than surrounding body text.

## Building a full custom theme

For apps with distinct visual identity, start from ``QuillTheme/default`` and override across token groups.
The pattern:

```swift
import QuillKit

var theme = QuillTheme.default

// Body
theme.body.font = .preferredFont(forTextStyle: .body)
theme.body.textColor = .label

// Headings
theme.heading.fontScales = [
    .relative(1.75), .relative(1.5), .relative(1.25),
    .relative(1.125), .relative(1), .relative(0.875)
]
theme.heading.fontWeights = [
    .bold, .bold, .semibold, .semibold, .medium, .medium
]

// Link
theme.link.color = .systemTeal
theme.link.underlineStyle = .single

// Code block
theme.codeBlock.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
theme.codeBlock.backgroundColor = .secondarySystemBackground
theme.codeBlock.cornerRadius = 8

// Blockquote
theme.blockquote.barColor = .systemGray4
theme.blockquote.barWidth = 3
theme.blockquote.textColor = .secondaryLabel

// Table
theme.table.separatorColor = .separator
theme.table.separatorWidth = 1
theme.table.bodyFont = .systemFont(ofSize: 14)
```

Every token group listed above is mutable -- the theme struct is open to customization at the property level, with no protocol-conformance requirement.

If a specific token is missing from this example, it exists in ``QuillTheme`` -- the full token list lives on the symbol reference page.

## Accessibility and theming

### Dynamic Type

Text-style-based fonts (`.preferredFont(forTextStyle:)`) scale with the user's content size preference.
Fixed-size fonts (`UIFont.systemFont(ofSize: 14)`) do not.

The bundled ``QuillTheme/default`` and ``QuillTheme/github`` presets currently use fixed-size system fonts for body and inline code.
For apps targeting users who rely on larger accessibility text sizes, override the relevant tokens with text-style-based fonts.
A reasonable baseline: set `theme.body.font = .preferredFont(forTextStyle: .body)` and replace code block fonts with scaled monospace variants.

### Contrast

Text color tokens should meet WCAG AA contrast ratios against their background -- 4.5:1 for body text, 3:1 for large text.
The default and GitHub presets target these thresholds using system colors (`.label`, `.secondaryLabel`) paired with system background surfaces.

If you customize a color token, verify contrast using Xcode's Accessibility Inspector or an online WCAG calculator.
Low-contrast custom themes look design-approved in Figma but fail for users with low vision or in high-glare conditions.

### Links distinguishable beyond color

WCAG guidance recommends links be distinguishable from body text by more than color alone.
``QuillTheme/Link`` exposes `underlineStyle` for this reason.
Colorblind users and users in high-glare conditions benefit from underlined links even when color contrast is adequate.

## See Also

- <doc:GettingStarted> -- integrating Quill with basic configuration
- <doc:StreamingPresets> -- tuning streaming pacing (complements visual theming)
- <doc:Integrations> -- combining themes with syntax highlighting for code blocks
- ``QuillTheme`` -- the symbol reference for all token properties
- ``QuillConfiguration`` -- where theme is applied in a rendering context
