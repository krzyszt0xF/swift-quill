# ``QuillTheme/Body``

Token group for body (paragraph) text styling.

## Overview

Controls font and text color for standard paragraph content. Body styling serves as the baseline -- headings derive from body via relative font scales, inline code offsets relative to body.

## Topics

### Properties

- ``font``
- ``textColor``
- ``init(font:textColor:)``

## ``font``

The base `UIFont` for body text. For Dynamic Type support, use `.preferredFont(forTextStyle: .body)`.

## ``textColor``

Foreground color for body text. Use `UIColor` dynamic providers or system semantic colors (`.label`) for light/dark adaptation.

## ``init(font:textColor:)``

Creates a Body token group.

- Parameter font: The base font for body text.
- Parameter textColor: The foreground color for body text.
