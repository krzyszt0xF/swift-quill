# ``QuillTheme/Image``

Token group for standalone image block rendering.

## Overview

Controls placeholder colors, error state colors, fallback aspect ratio, and maximum display height for image blocks rendered through ``ImageLoading``.

## Topics

### Properties

- ``altTextColor``
- ``cornerRadius``
- ``errorIconColor``
- ``fallbackAspectRatio``
- ``maxHeight``
- ``placeholderColor``
- ``init(altTextColor:cornerRadius:errorIconColor:fallbackAspectRatio:maxHeight:placeholderColor:)``

## ``altTextColor``

Color for alt-text rendering when an image fails to load or when no ``ImageLoading`` is configured.

## ``cornerRadius``

Corner radius applied to the rendered image in points.

## ``errorIconColor``

Color of the error icon displayed when image loading fails after retries.

## ``fallbackAspectRatio``

Default aspect ratio (width/height) used for the placeholder before intrinsic size is known.

## ``maxHeight``

Maximum display height of images in points. Images taller than this are scaled down proportionally.

## ``placeholderColor``

Background color of the image placeholder shown while loading.

## ``init(altTextColor:cornerRadius:errorIconColor:fallbackAspectRatio:maxHeight:placeholderColor:)``

Creates an Image token group.

- Parameter altTextColor: Color for alt-text when image loading fails.
- Parameter cornerRadius: Corner radius of the rendered image.
- Parameter errorIconColor: Color of the error icon.
- Parameter fallbackAspectRatio: Default aspect ratio for the placeholder.
- Parameter maxHeight: Maximum display height in points.
- Parameter placeholderColor: Background color of the placeholder.
