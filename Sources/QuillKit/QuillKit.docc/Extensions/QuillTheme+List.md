# ``QuillTheme/List``

Token group for list marker and indentation styling.

## Overview

Controls bullet and task-list marker characters, nested list indentation, and vertical spacing between list items.

## Topics

### Properties

- ``bulletMarker``
- ``checkedMarker``
- ``indentPerLevel``
- ``itemSpacing``
- ``uncheckedMarker``
- ``init(bulletMarker:checkedMarker:indentPerLevel:itemSpacing:uncheckedMarker:)``

## ``bulletMarker``

Character used as the bullet for unordered list items, typically a Unicode bullet (`"\u{2022}"`).

## ``checkedMarker``

Character used for checked task list items, typically a Unicode checked box (`"\u{2611}"`).

## ``indentPerLevel``

Horizontal indentation added per nesting level, as a ``SpacingValue``.

## ``itemSpacing``

Vertical spacing between list items within the same level, as a ``SpacingValue``.

## ``uncheckedMarker``

Character used for unchecked task list items, typically a Unicode ballot box (`"\u{2610}"`).

## ``init(bulletMarker:checkedMarker:indentPerLevel:itemSpacing:uncheckedMarker:)``

Creates a List token group.

- Parameter bulletMarker: Character for unordered list bullets.
- Parameter checkedMarker: Character for checked task list items.
- Parameter indentPerLevel: Indentation per nesting level.
- Parameter itemSpacing: Vertical spacing between items.
- Parameter uncheckedMarker: Character for unchecked task list items.
