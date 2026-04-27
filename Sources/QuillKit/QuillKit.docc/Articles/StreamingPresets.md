# Streaming Presets

Tune perceived pacing of tail updates -- from character-by-character typewriter pace to batched block-level reveal.

@Metadata {
    @PageKind(article)
    @PageColor(orange)
}

## Overview

Quill's streaming pipeline determines when rendered content updates relative to incoming chunks.
By default, it uses the ``QuillStreamingPreset/balanced`` preset -- a middle ground between responsive feel and batched stability.

The preset system exposes three named presets plus two custom variants:

- ``QuillStreamingPreset/balanced`` -- the default, tuned for typical LLM streaming rates.
- ``QuillStreamingPreset/snappy`` -- faster tail updates for character-by-character feel.
- ``QuillStreamingPreset/longForm`` -- slower, more stable updates for documents under long generation.
- ``QuillStreamingPreset/custom(speedMultiplier:bufferingDelay:)`` -- explicit tuning of tick rate and debounce.
- ``QuillStreamingPreset/bufferedCustom(speedMultiplier:bufferingDelay:minModuleLength:)`` -- custom tuning with an additional minimum-module-length guard.

Streaming presets affect visual perception, not raw performance.
The underlying pipeline -- parsing, diff, TextKit 2 fragment updates -- runs identically regardless of preset.

## Choosing a preset

### When to use balanced

The default preset, appropriate for the majority of AI chat integrations.
Tuned for token rates typical of hosted LLMs (50-200 tokens/second from major providers).
Provides responsive-feeling tail updates without over-mutating the rendered document on every small chunk.

Use balanced unless you have specific reason to change.

### When to use snappy

Tail updates apply more aggressively, producing a character-by-character "typewriter" feel.
Best for:

- Small-window chat bubbles where tail reveal matters perceptually.
- UI testing with recorded streams where you want every chunk visible.
- Client-side streaming from local models where chunks may be single tokens.

The tradeoff is more frequent TextKit 2 fragment updates.
On older devices, this may be visible as a slight frame-time increase (still within the main thread budget, but closer to it).
For most modern iOS hardware, snappy is indistinguishable from balanced in frame time.

### When to use longForm

Tail updates apply less frequently, favoring block-level reveal over per-chunk updates.
Best for:

- Long-form document generation (reports, summaries, code walkthroughs) where frequent tail updates would produce visual noise.
- Lower-end devices where minimizing update frequency yields measurably better frame times.
- Stylized "thoughtful" UX where a slower reveal signals careful generation.

The tradeoff is a perceptual delay between chunk arrival and visible update.
For fast LLM streams, this can feel like the model is "thinking" before writing -- in some contexts, this is a feature.

### When to use custom

Use `.custom` when none of the named presets match your use case.
Two parameters control pacing:

- **`speedMultiplier: Double`** -- scalar applied to the internal tick rate; higher values update more frequently.
- **`bufferingDelay: TimeInterval`** -- debounce interval (in seconds) between chunk-triggered updates.

See ``QuillStreamingPreset`` for accepted value ranges and default guidance.
Custom presets are useful for A/B testing different feels or matching a very specific UX design; for production integrations, one of the three named presets usually fits.

### When to use bufferedCustom

A custom preset with an additional guard on minimum module length before a complete block flushes out of the tail.
Useful when working with streams that emit small incremental modules (very short paragraphs, code fragments) where forcing a larger minimum chunk keeps the reveal rhythm steady.

Parameters:

- **`speedMultiplier: Double`** -- same meaning as in `.custom`.
- **`bufferingDelay: TimeInterval`** -- same meaning as in `.custom`.
- **`minModuleLength: Int`** -- minimum character count for a block to promote out of the active tail.

Use `bufferedCustom` only when `custom` is not enough; for most tuning needs, `custom`'s two parameters suffice.

## Applying a preset

Presets are set via ``QuillConfiguration``:

```swift
let configuration = QuillConfiguration(
    streaming: .init(preset: .snappy),
    theme: .github
)
```

For SwiftUI:

```swift
QuillStreamView(
    chunks: chunks,
    streamID: messageID,
    configuration: configuration
)
```

For UIKit:

```swift
let quillView = QuillView(configuration: configuration)
```

The preset is read at configuration time and applies to all chunks processed under that configuration.
To change presets mid-stream, create a new ``QuillConfiguration`` with the new preset -- the next `append` call picks up the change.
For SwiftUI, binding a new configuration to ``QuillStreamView`` triggers the update.

## Per-message preset selection

Some apps benefit from different presets per message type.
A short acknowledgment ("Got it.") might feel best with `.snappy` typewriter reveal; a long technical answer might feel better with `.longForm`.

Because ``QuillConfiguration`` is a value type, creating per-message configurations is cheap:

```swift
func preset(for message: Message) -> QuillStreamingPreset {
    switch message.kind {
    case .shortReply:
        return .snappy
    case .longAnswer:
        return .longForm
    case .general:
        return .balanced
    }
}

let configuration = QuillConfiguration(
    streaming: .init(preset: preset(for: message)),
    theme: .github
)
```

Apply the configuration per ``QuillStreamView`` instance.
Each message's view computes its own preset based on the message type.

Do not mix this with dynamic preset switching mid-stream on the same message -- creating new configurations for the same `streamID` risks resetting the visible tail.
The preset decision should be final at the start of each response.

## Streaming presets and device performance

Presets affect update frequency, not parse cost.
The off-main parser runs once per chunk regardless of preset.
What changes is how many of those parse results trigger visible TextKit 2 updates.

`.snappy` produces the most per-second UI updates; `.longForm` produces the fewest.
On modern iOS hardware (iPhone 12+), all three named presets fit well within main-thread frame budgets during typical LLM streaming rates.
On older hardware, or with very high token rates (1000+ tokens/second from a local model), `.longForm` provides measurable frame-time headroom.

For measurements of actual update frequencies and frame-time impact across devices, see [Docs/Performance.md](https://github.com/krzyszt0xF/swift-quill/blob/main/Docs/Performance.md).

## See Also

- <doc:StreamingConcepts> -- how streaming and the frozen prefix / active tail model work
- <doc:GettingStarted> -- basic configuration and integration
- <doc:CustomizingTheme> -- visual theming (complements streaming pacing)
- ``QuillStreamingPreset`` -- the symbol reference for preset cases and custom parameters
- ``QuillConfiguration`` -- where presets are applied
