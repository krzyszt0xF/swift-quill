# Image-heavy scenario

This scenario exercises the image-loading path. Toggle **Image loading** off on the config screen to compare the placeholder behavior.

All images below are served by the Lorem Picsum API (https://picsum.photos) which provides deterministic placeholders for a given seed. The seeds are chosen so the rendered images stay consistent across runs.

## Landscape

A wide image that should occupy the full available width.

![Mountain seed](https://picsum.photos/seed/mountain/800/400)

## Two inline candidates

A pair of smaller images rendered one after the other. Note how Quill waits for each image to settle before adjusting surrounding layout.

![Forest seed](https://picsum.photos/seed/forest/600/300)

![Coast seed](https://picsum.photos/seed/coast/600/300)

## Portrait

A taller aspect ratio. The layout engine respects the natural dimensions reported by the loader.

![Portrait seed](https://picsum.photos/seed/portrait/400/600)

## Square

Useful for avatars and tile-style thumbnails.

![Square seed](https://picsum.photos/seed/square/500/500)

## Mixed prose and images

Text between images shouldn't reflow awkwardly. **Bold** and *italic* phrases stay in place while the images load and settle.

![Interleaved seed](https://picsum.photos/seed/interleaved/600/300)

Sometimes a caption follows the image directly. The renderer treats it as a regular paragraph — no special handling.

![Caption seed](https://picsum.photos/seed/caption/600/300)

*Loaded via Lorem Picsum — https://picsum.photos.*
