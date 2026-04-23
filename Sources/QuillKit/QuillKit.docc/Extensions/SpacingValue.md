# ``SpacingValue``

Spacing or sizing token that can be absolute or relative to body font size.

## Overview

``SpacingValue`` represents a measurement that can either be expressed as an absolute value in points (``absolute(_:)``) or as a multiplier of the body font size (``relative(_:)``).
This enables theme tokens to adapt to different base font sizes -- a heading with `fontScale` of `.relative(2.0)` always renders at twice the body size regardless of what that body size is set to.

``SpacingValue`` conforms to both `ExpressibleByFloatLiteral` and `ExpressibleByIntegerLiteral`, so you can write:

```swift
theme.spacing.blockSpacing = 12  // becomes .absolute(12)
theme.heading.spacingBefore = 0.75  // becomes .absolute(0.75)
```

Integer and float literals default to ``absolute(_:)``.
For relative values, use the case explicitly:

```swift
theme.heading.spacingBefore = .relative(0.5)
```

## Topics

### Cases

- ``absolute(_:)``
- ``relative(_:)``

### Computing a concrete value

- ``scale(against:)``

### Creating from literals

- ``init(floatLiteral:)``
- ``init(integerLiteral:)``

## ``absolute(_:)``

A spacing value specified directly in points.

- Parameter value: The value in points.

## ``relative(_:)``

A spacing value specified as a multiplier of the body font size.

- Parameter multiplier: The multiplier applied to body font size to derive the final value.

## ``scale(against:)``

Resolves this value to a concrete point measurement.

- Parameter bodyFontSize: The body font size in points, used as the reference for ``relative(_:)`` values.
- Returns: The resolved value in points. Absolute values pass through unchanged; relative values are multiplied by `bodyFontSize`.

## ``init(floatLiteral:)``

Initializes a ``SpacingValue`` from a float literal as ``absolute(_:)``.

- Parameter value: The literal value.

For relative values, use ``relative(_:)`` explicitly.

## ``init(integerLiteral:)``

Initializes a ``SpacingValue`` from an integer literal as ``absolute(_:)``.

- Parameter value: The literal value (converted to `CGFloat` internally).

For relative values, use ``relative(_:)`` explicitly.
