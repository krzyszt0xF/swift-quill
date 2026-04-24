# ``QuillTheme/Heading``

Token group for headings H1 through H6.

## Overview

Controls font scales, weights, and spacing before for the six Markdown heading levels. Scales and weights are arrays indexed by level.

## Topics

### Properties

- ``fontScales``
- ``fontWeights``
- ``spacingBefore``

### Methods

- ``fontScale(for:)``
- ``fontWeight(for:)``
- ``init(fontScales:fontWeights:spacingBefore:)``

## ``fontScales``

Array of font scale values, indexed by heading level (0 = H1, 5 = H6). Each element is a ``SpacingValue`` multiplier applied to body font size. Arrays shorter than 6 elements reuse the last entry.

## ``fontWeights``

Array of `UIFont.Weight` values, indexed by heading level (0 = H1, 5 = H6). Arrays shorter than 6 elements reuse the last entry.

## ``spacingBefore``

Vertical spacing applied above each heading, as a ``SpacingValue``.

## ``fontScale(for:)``

Returns the font scale for a given heading level.

- Parameter level: The heading level (1 through 6, clamped to range).
- Returns: The ``SpacingValue`` scale applied to body font size for that heading level.

## ``fontWeight(for:)``

Returns the font weight for a given heading level.

- Parameter level: The heading level (1 through 6, clamped to range).
- Returns: The `UIFont.Weight` for that heading level.

## ``init(fontScales:fontWeights:spacingBefore:)``

Creates a Heading token group.

- Parameter fontScales: Array of scale values per level.
- Parameter fontWeights: Array of weights per level.
- Parameter spacingBefore: Vertical spacing above each heading.
