# ``QuillTheme/Table``

Token group for GFM table rendering.

## Overview

Controls fonts, cell padding, minimum row height, and separator styling for Markdown tables.

## Topics

### Properties

- ``bodyFont``
- ``cellPadding``
- ``headerFont``
- ``minimumRowHeight``
- ``separatorColor``
- ``separatorWidth``
- ``init(bodyFont:cellPadding:headerFont:minimumRowHeight:separatorColor:separatorWidth:)``

## ``bodyFont``

Font for table body cells.

## ``cellPadding``

Edge insets applied inside each cell, controlling whitespace around cell content.

## ``headerFont``

Font for table header cells (first row). Typically a semibold variant of ``bodyFont``.

## ``minimumRowHeight``

Minimum height of each table row in points. Rows with taller content expand naturally.

## ``separatorColor``

Color of the row and column separator lines.

## ``separatorWidth``

Width of separator lines in points. Zero for no separators.

## ``init(bodyFont:cellPadding:headerFont:minimumRowHeight:separatorColor:separatorWidth:)``

Creates a Table token group.

- Parameter bodyFont: Font for body cells.
- Parameter cellPadding: Edge insets inside each cell.
- Parameter headerFont: Font for header cells.
- Parameter minimumRowHeight: Minimum row height in points.
- Parameter separatorColor: Color of separator lines.
- Parameter separatorWidth: Width of separator lines in points.
