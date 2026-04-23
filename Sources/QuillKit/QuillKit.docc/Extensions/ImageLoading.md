# ``ImageLoading``

Protocol for loading images referenced by URL in Markdown content.

## Overview

``ImageLoading`` is the extension point for image loading. Conform to provide image fetching; Quill calls ``ImageLoading/loadImage(from:)`` when a standalone image block promotes out of the active tail.

For a `URLSession`-backed loader with in-memory caching, use `QuillImageLoader.ImageLoader.default`. For integration with Nuke, Kingfisher, or custom pipelines (authenticated fetches, internal CDNs), conform to ``ImageLoading`` directly.

See <doc:Integrations> for implementation recipes with specific libraries.

### Threading

``ImageLoading/loadImage(from:)`` is an async throwing method. Quill invokes it from a background task and applies the returned image on the main actor. Implementations do not need to handle main-actor delivery themselves.

## Topics

### Required

- ``loadImage(from:)``

## ``loadImage(from:)``

Fetches and decodes an image from a URL.

- Parameter url: The image URL as written in the Markdown source.
- Returns: The decoded `UIImage` ready for display.
- Throws: Any error from the underlying fetch or decode operation. Quill handles errors by rendering a placeholder.

Implementations can use `URLSession`, Nuke's `ImagePipeline`, Kingfisher's `KingfisherManager`, or any other image loading mechanism.

The URL is the raw string from the Markdown source -- validate as needed for your security model (HTTPS-only, allowed hosts, authentication headers, and similar).
