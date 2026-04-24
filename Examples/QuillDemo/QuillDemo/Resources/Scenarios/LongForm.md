# The calm math of streaming rendering

Streaming a language model response to a reader sounds straightforward. A server emits tokens. A client accumulates them. The view displays whatever has arrived. In practice, naive implementations thrash. Each new chunk invalidates layout, the text reflows, previously visible lines shift by fractions of a pixel, and the cumulative effect is a reading surface that wobbles instead of growing. The calm we associate with reading — letters appearing exactly where they settled — is the first casualty of doing the obvious thing.

Quill exists because the obvious thing is not good enough.

## Why generic markdown renderers fall short

A markdown renderer meant for static documents assumes its input is complete. It parses, lays out once, and hands the result to a view. When the same renderer is asked to re-parse on every chunk, two problems appear at once.

The first is layout churn. Any renderer that returns an attributed string or a view tree per update forces the parent view to re-measure, re-lay-out, and re-draw. When that happens ten times per second, the reader sees a screen that is in constant motion. The sensation is not scrolling — it is twitching.

The second is semantic ambiguity. Until the stream emits the closing fence of a code block, the renderer does not know whether the current text is code or prose. It must guess, commit to a rendering, and then undo that choice when the actual boundary arrives. The viewer sees letters transmute from monospaced to proportional as the parse stabilizes. Nothing about this is pleasant.

## Segmentation and promotion

Quill resolves both problems at the cost of a more elaborate pipeline. Incoming markdown is decomposed into a block-level AST, and each block is converted into a flow of smaller, independently measurable segments. Stable prefixes of a segment are promoted to the rendering tree only when their structure cannot be retracted by a later chunk. An in-progress code block remains pending until its language tag and the first content line commit; an in-progress list item delays promotion until it can distinguish itself from a continued paragraph.

The net effect is that the visible layer moves rarely. When it does move, it moves because something real has settled, not because a guess has changed its mind.

## Presets as contracts

A streaming preset is, in the language of this library, a contract about what matters. `Balanced` is the default: reveal is smooth and responsive for typical chat-length responses. `Snappy` reduces buffering at the cost of more frequent segment promotions; it is the right choice when the model emits small tokens quickly. `LongForm` accepts more buffering and wider segment windows in exchange for flow stability across paragraphs; it is the right choice when the response is several screens long and the reader will scroll through it.

The two `custom` cases — `custom(speedMultiplier:, bufferingDelay:)` and `bufferedCustom(speedMultiplier:, bufferingDelay:, minModuleLength:)` — expose the knobs directly for callers who know what they need. The defaults of the balanced case are chosen to be plausible on mid-range iPhones without touching the knobs at all.

## Themes and restraint

Theming in Quill is deliberately narrow. Eleven token groups cover the entire markdown surface, and each group holds a handful of properties that compose into a `QuillTheme` value. The library ships `.default` and `.github`. A consumer who wants their own look passes a value; the library does not attempt to run a theming DSL or parse style sheets. The narrowness is the point — a library that protects its layout contract cannot let itself be reconfigured into a shape it cannot defend.

## Integrations

Syntax highlighting and image loading are configured by modifiers on the consuming view, not by flags on the configuration value. A call site writes `.quill.setHighlighter(SyntaxHighlighter.default)` when it wants code blocks styled, and `.quill.setImageLoader(ImageLoader.default)` when it wants images fetched. Passing `nil` disables the integration; the absence of a highlighter produces plain monospaced code, and the absence of a loader produces a stable placeholder where an image would be.

Both integrations live in their own modules — `QuillHighlight` and `QuillImageLoader` — so a consumer who needs neither can link only `QuillKit` and `QuillSwiftUI`.

## What streaming identity buys

The `streamID` parameter on `QuillStreamView` is a small API with a precise job. When the caller swaps one identity for another, the view interprets the change as *a new stream begins* and cancels whatever was in flight. This is the library's contribution to the most common mistake in streaming UI: continuing to append chunks from an abandoned request onto the surface of a newer one, producing a tangled transcript that no reader can parse.

In practice, callers pass the message identifier as the stream ID. When a user edits the prior message and the chat re-requests, the identifier stays the same and the existing stream is reused. When the chat moves on to the next message, the identifier changes and the old subscription is cleanly torn down.

## Closing thoughts

The right way to build a streaming markdown view is to accept, up front, that the medium is harder than it looks. Reading is a private, concentrated act. A wobbling page interrupts the reader more than a slower one. Quill is opinionated about this trade-off because the library's authors believe the alternative — a generic renderer tuned after the fact — cannot recover the quiet that streaming content should feel like.

Pick a preset, pass your chunks, and let the rest happen quietly.
