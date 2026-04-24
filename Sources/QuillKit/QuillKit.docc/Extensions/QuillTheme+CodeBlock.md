# ``QuillTheme/CodeBlock``

Token group for fenced code block styling.

## Overview

Controls fonts, colors, padding, border, corner radius, copy button, and language label appearance for fenced code blocks.

## Topics

### Properties

- ``backgroundColor``
- ``borderColor``
- ``borderWidth``
- ``copyButtonTint``
- ``cornerRadius``
- ``font``
- ``headerFont``
- ``languageLabelColor``
- ``lineSpacing``
- ``padding``
- ``textColor``
- ``init(backgroundColor:borderColor:borderWidth:copyButtonTint:cornerRadius:font:headerFont:languageLabelColor:lineSpacing:padding:textColor:)``

## ``backgroundColor``

Background color of the code pane.

## ``borderColor``

Border color of the code pane.

## ``borderWidth``

Border width in points. Zero for no border.

## ``copyButtonTint``

Tint color for the copy-to-clipboard button in the code block header.

## ``cornerRadius``

Corner radius of the code pane in points.

## ``font``

Monospace font for code content. Typically Menlo or `.monospacedSystemFont(ofSize:weight:)`.

## ``headerFont``

Font for the language label in the code block header.

## ``languageLabelColor``

Color of the language label text in the code block header.

## ``lineSpacing``

Line spacing within the code pane, in points.

## ``padding``

Internal padding of the code pane, in points.

## ``textColor``

Foreground color for code content when no syntax highlighter is configured. When a ``SyntaxHighlighting`` conformer is set, it may override per-token colors.

## ``init(backgroundColor:borderColor:borderWidth:copyButtonTint:cornerRadius:font:headerFont:languageLabelColor:lineSpacing:padding:textColor:)``

Creates a CodeBlock token group.

- Parameter backgroundColor: Code pane background color.
- Parameter borderColor: Border color of the code pane.
- Parameter borderWidth: Border width in points.
- Parameter copyButtonTint: Tint for the copy button.
- Parameter cornerRadius: Corner radius of the code pane in points.
- Parameter font: Monospace font for code content.
- Parameter headerFont: Font for the language label in the header.
- Parameter languageLabelColor: Color of the language label.
- Parameter lineSpacing: Line spacing within the code pane.
- Parameter padding: Internal padding in points.
- Parameter textColor: Foreground color for code content.
