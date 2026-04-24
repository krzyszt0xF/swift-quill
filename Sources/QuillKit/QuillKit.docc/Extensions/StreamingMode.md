# ``StreamingMode``

Low-level streaming mode controlling how the pipeline processes chunks.

## Overview

``StreamingMode`` determines the structural approach of Quill's streaming pipeline: whether content flows through as smoothed tail updates or buffers into modules before emission.

Most applications should not need to change this.
The default mode (`.smoothedTail`) is tuned for typical AI chat integrations.
``StreamingMode`` exists as an escape hatch for advanced use cases where the default structure does not fit.

For pacing control (the typical customization axis), use ``QuillStreamingPreset`` instead -- see <doc:StreamingPresets>.

### Relationship to presets

``StreamingMode`` and ``QuillStreamingPreset`` control orthogonal aspects:

- ``StreamingMode`` controls how the pipeline is structured (smoothed vs buffered)
- ``QuillStreamingPreset`` controls how often updates reach the screen

In most integrations, the default mode (`.smoothedTail`) combined with a named preset from ``QuillStreamingPreset`` provides appropriate behavior.
Change ``StreamingMode`` only when you have measured evidence that the default mode is the wrong choice for your content source.

## Topics

### Modes

- ``smoothedTail``
- ``bufferedModules``

## ``smoothedTail``

Default mode.
Chunks flow through the pipeline with tail updates smoothed across main-thread frames.

Appropriate for typical LLM streaming where chunks arrive at rates that benefit from moderate smoothing.
Combined with ``QuillStreamingPreset/balanced`` (also default), this is the path most integrations should use.
No configuration is required to use this mode -- it is the default when `QuillConfiguration.Streaming` is initialized with no arguments.

## ``bufferedModules``

Advanced mode.
Chunks accumulate into module-level units before emission to the pipeline.

Useful for streams with very small chunks (single tokens from a local model) where smoothing alone produces visible noise.
Combined with ``QuillStreamingPreset/bufferedCustom(speedMultiplier:bufferingDelay:minModuleLength:)``, this mode provides fine-grained control over reveal rhythm.

Most applications should use ``smoothedTail`` instead.
If you find yourself reaching for ``bufferedModules``, first try ``QuillStreamingPreset/longForm`` -- it often addresses the same concerns without changing the pipeline mode.
