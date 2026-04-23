# ``QuillTheme/Inline``

Token group for inline code styling (backticks within prose).

## Overview

Controls background, text color, and font size offset for inline code fragments. Separate from fenced code blocks.

## Topics

### Properties

- ``backgroundColor``
- ``fontSizeOffset``
- ``textColor``
- ``init(backgroundColor:fontSizeOffset:textColor:)``

## ``backgroundColor``

Background color applied behind inline code text, typically a subtle fill like `.systemGray6`.

## ``fontSizeOffset``

Font size offset applied to inline code, in points, relative to body font size. Negative values render inline code slightly smaller than surrounding body text.

## ``textColor``

Foreground color for inline code text.

## ``init(backgroundColor:fontSizeOffset:textColor:)``

Creates an Inline token group.

- Parameter backgroundColor: Background color behind inline code.
- Parameter fontSizeOffset: Font size offset relative to body in points.
- Parameter textColor: Foreground color for inline code text.
