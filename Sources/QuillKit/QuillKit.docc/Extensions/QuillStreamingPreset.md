# ``QuillStreamingPreset``

Streaming behavior preset controlling perceived pacing of tail updates.

## Overview

``QuillStreamingPreset`` determines when the rendered document updates relative to incoming chunks.
Three named presets cover common pacing tradeoffs; two custom variants allow explicit parameter tuning.

Presets affect visual perception, not raw performance.
The underlying pipeline -- parsing, diff, TextKit 2 fragment updates -- runs identically regardless of preset.
The choice of preset controls how often updates become visible, not how expensive each update is.
Readers familiar with frame-rate discussion should note: presets do not change the per-update cost, only the update cadence.

For detailed guidance on choosing a preset, see <doc:StreamingPresets>.

### Per-message selection

``QuillStreamingPreset`` is a value type with `Hashable` conformance.
It is cheap to store, compare, and pass between views.
For apps that benefit from different presets per message (short replies using ``snappy``, long answers using ``longForm``), compute the preset from message metadata and pass it through ``QuillConfiguration/Streaming``.

Do not switch presets mid-stream on the same message.
The preset is read at ``QuillConfiguration`` creation time and applies uniformly to the stream subscription.
If mid-stream re-pacing is a real requirement, drive it through ``QuillView/cancelStreaming()`` + ``QuillView/reset()`` with a new configuration.

### Relationship to StreamingMode

``QuillStreamingPreset`` controls update frequency; ``StreamingMode`` controls pipeline structure.
The two are orthogonal -- most integrations keep ``StreamingMode`` at its default (`.smoothedTail`) and tune only the preset.

Change presets freely without touching ``StreamingMode``.
Change ``StreamingMode`` only for advanced use cases documented in its own reference.

### Choosing between named presets

The three named presets map to three pacing expectations:

- ``balanced`` when you want "feels live but not frantic"
- ``snappy`` when every chunk should be visible immediately
- ``longForm`` when the content is long and you want calm block-level reveals

## Topics

### Named presets

- ``balanced``
- ``snappy``
- ``longForm``

### Custom presets

- ``custom(speedMultiplier:bufferingDelay:)``
- ``bufferedCustom(speedMultiplier:bufferingDelay:minModuleLength:)``

## ``balanced``

The default preset, tuned for typical LLM streaming rates (50-200 tokens/second from major providers).

Provides responsive-feeling tail updates without over-mutating the rendered document on every small chunk.
Use as the default for AI chat integrations.
Does not require any explicit configuration -- appears by default when ``QuillConfiguration/Streaming`` is initialized with no arguments.

## ``snappy``

More aggressive tail updates, producing a character-by-character typewriter feel.

Best for:

- Small-window chat bubbles where tail reveal matters perceptually
- UI testing with recorded streams where every chunk should be visible
- Client-side streaming from local models with single-token chunks

Tradeoff: more frequent TextKit 2 fragment updates.
On modern iOS hardware (iPhone 12+), indistinguishable from ``balanced`` in frame time.
On older devices or with very high chunk rates, prefer ``balanced`` or ``longForm``.

## ``longForm``

Less frequent tail updates, favoring block-level reveal over per-chunk updates.

Best for:

- Long-form document generation (reports, summaries, code walkthroughs)
- Lower-end devices where minimizing update frequency yields measurable frame-time improvements
- Stylized "thoughtful" UX where a slower reveal signals careful generation

Tradeoff: a perceptual delay between chunk arrival and visible update.
For fast LLM streams, this can feel like the model is "thinking" before writing.
For some products this is a feature rather than a bug -- slower reveal can signal deliberation.

## ``custom(speedMultiplier:bufferingDelay:)``

A custom preset with explicit tuning of tick rate and debounce.

- Parameter speedMultiplier: Scalar applied to the internal tick rate. Higher values update more frequently.
- Parameter bufferingDelay: Debounce interval (in seconds) between chunk-triggered updates.

Use when none of the named presets match your use case.
For production integrations, one of the named presets usually fits.
If you need to tune these parameters, start from the semantics of the named preset closest to your needs, then adjust in small increments.

## ``bufferedCustom(speedMultiplier:bufferingDelay:minModuleLength:)``

A custom preset with an additional minimum-module-length guard.

- Parameter speedMultiplier: Same meaning as in ``custom(speedMultiplier:bufferingDelay:)``.
- Parameter bufferingDelay: Same meaning as in ``custom(speedMultiplier:bufferingDelay:)``.
- Parameter minModuleLength: Minimum character count for a block to promote out of the active tail.

Useful with streams that emit small incremental modules (very short paragraphs or code fragments).
Forcing a larger minimum chunk keeps the reveal rhythm steady.

Use ``bufferedCustom(speedMultiplier:bufferingDelay:minModuleLength:)`` only when ``custom(speedMultiplier:bufferingDelay:)`` is not enough.
For most tuning needs, the two-parameter ``custom(speedMultiplier:bufferingDelay:)`` variant suffices.
The additional `minModuleLength` parameter is an advanced lever; it interacts with ``StreamingMode/bufferedModules`` to control buffer granularity.

### Custom presets and StreamingMode

``custom`` and ``bufferedCustom`` are independent of ``StreamingMode``.
Both work with the default ``StreamingMode/smoothedTail``.
``bufferedCustom`` integrates particularly well with ``StreamingMode/bufferedModules`` when you need explicit buffer-length control.
