# ``QuillTheme/Blockquote``

Token group for blockquote styling.

## Overview

Controls the blockquote bar decoration, text color, and per-level indent spacing for nested blockquotes.

## Topics

### Properties

- ``barColor``
- ``barCornerRadius``
- ``barLeadingInset``
- ``barWidth``
- ``levelSpacing``
- ``textColor``
- ``init(barColor:barCornerRadius:barLeadingInset:barWidth:levelSpacing:textColor:)``

## ``barColor``

Color of the vertical bar decoration on the left of the blockquote.

## ``barCornerRadius``

Corner radius of the blockquote bar in points. Small values (1-2 points) soften edges subtly.

## ``barLeadingInset``

Horizontal offset in points from the blockquote's leading edge to the bar.

## ``barWidth``

Width of the blockquote bar in points. Typical values range from 2 to 4 points.

## ``levelSpacing``

Additional indentation per nesting level, expressed as a ``SpacingValue``.

## ``textColor``

Foreground color for blockquote text. Typically `.secondaryLabel` or a comparable de-emphasized color.

## ``init(barColor:barCornerRadius:barLeadingInset:barWidth:levelSpacing:textColor:)``

Creates a Blockquote token group.

- Parameter barColor: Color of the vertical bar decoration.
- Parameter barCornerRadius: Corner radius of the bar in points.
- Parameter barLeadingInset: Horizontal offset from leading edge to the bar.
- Parameter barWidth: Width of the bar in points.
- Parameter levelSpacing: Additional indentation per nesting level.
- Parameter textColor: Foreground color for blockquote text.
