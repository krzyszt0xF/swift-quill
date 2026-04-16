# Performance

Benchmark methodology and measurements for Quill's rendering pipeline.

These benchmarks document measured performance on a specific device under controlled conditions. Results will vary on different hardware, OS versions, build configurations, and content complexity.

Treat these numbers as evidence for Quill's architecture and regression targets, not as a universal performance guarantee or a cross-library benchmark.

## Where this fits

This document covers **measured performance and implementation rationale** — what the numbers are, how they were measured, and why Quill's architecture achieves them. If you want the mental model for *using* Quill's streaming (frozen prefix, active tail, API lifecycle), see [Streaming Concepts](https://swiftpackageindex.com/krzyszt0xF/swift-quill/documentation/quillkit/streamingconcepts) in the DocC documentation.

## Reference Device

| Property | Value |
|----------|-------|
| Device | iPhone 15 Pro Max 256 GB |
| iOS version | 26.4 |
| Build configuration | Release |
| Date | 2026-04-11 |

## Test 1: Static Render -- 16ms Stall Threshold

**Result: PASS**

A 10KB+ static document (paragraphs, headings, lists, code blocks, tables, images) is rendered in a single pass. The threshold is that no main-thread stall exceeds 16ms (one frame at 60fps).

| Metric | Value |
|--------|-------|
| parseStatic max | 7.53ms (off-main) |
| parseStatic avg | 4.04ms (off-main) |
| render max (main) | 149.9us |
| reduce max (main) | 41.5us |
| measureHeight max (main) | 677.6us |
| **Combined max main-thread work** | **~870us** |

Parse runs off the main thread via a nonisolated static helper. Confirmed in Instruments signpost track under `com.quill.pipeline > Parse` category. Max combined main-thread Quill work per static render cycle is under 1ms, well below the 16ms threshold.

## Test 2: Streaming -- Smooth Append Throughput

**Result: PASS**

A 500+ line streaming session with continuous `append` calls. The threshold is zero sustained frame drops with p95 frame time under 16ms.

| Metric | Value |
|--------|-------|
| render count | 2,552 |
| render avg | 1.43ms |
| render max | 4.38ms |
| reduce avg | 28.0us |
| reduce max | 218.8us |
| measureHeight avg | 914us |
| measureHeight max | 3.18ms |
| Dropped frames | **0** |

Render average of 1.43ms is well under the 16ms frame budget. Zero dropped frames across 2,552 render calls. The max render spike of 4.38ms is isolated, not sustained.

## Test 3: Memory -- Bounded After Repeated Streaming

**Result: PASS**

Three consecutive stream-reset-stream cycles with the same content. Memory is measured post-idle (after reset completes and autoreleasepool drains). The threshold is no monotonic growth exceeding 5 MiB or 10%.

| Run | Post-idle memory (All Heap & Anonymous VM, Persistent) |
|-----|-------------------------------------------------------|
| 1   | 31.94 MiB |
| 2   | 32.08 MiB |
| 3   | 31.33 MiB |

Max variance is 0.75 MiB (Run 1 to Run 3). No monotonic growth -- Run 3 is lower than Run 1. Well within the 5 MiB / 10% tolerance.

## Why Quill Is Fast

### Off-main parsing

Markdown parsing uses a nonisolated static helper with owned `Task` lifetime. The parse result is awaited and applied on the main thread only after completion. `Task.isCancelled` guards after `await` prevent stale render application when the user resets or starts a new stream during parsing.

### Tail-only document mutation

During streaming, Quill splits content into a frozen prefix (fully rendered blocks) and an active tail (in-progress content). Only the tail is mutated on each `append` call. The frozen prefix is never re-rendered, re-measured, or touched by editing transactions. This bounds per-tick work to the size of the active tail, not the full document. For the user-facing mental model of frozen prefix vs active tail, see [Streaming Concepts](https://swiftpackageindex.com/krzyszt0xF/swift-quill/documentation/quillkit/streamingconcepts).

### Async enrichment never blocks rendering

Syntax highlighting and image loading run asynchronously and deliver results to the rendered document after completion. The render pipeline does not wait for enrichment -- code blocks appear with plain text immediately on fence close, and highlighted text replaces it when the highlighter finishes. Images show placeholders during loading. This means enrichment latency never contributes to frame time.

### Height coalescing

Height measurement is coalesced to avoid redundant work. Multiple rapid content changes (common during streaming) are batched so the host view measures height once per display cycle rather than once per append call.

### Bounded memory via reset/cancel lifecycle

The `reset()` method clears all content, cancels in-flight tasks (parsing, highlighting, image loading), and releases document state. The `cancelStreaming()` method stops streaming without clearing rendered content. Both paths ensure no leaked tasks or unbounded accumulation.

## Instrumentation

Quill includes `os_signpost` instrumentation at top-level pipeline entry points. When profiling with Instruments, look for:

- `com.quill.pipeline > Parse` -- static and streaming parse durations
- `com.quill.pipeline > Reduce` -- block reduction work
- `com.quill.pipeline > Render` -- document mutation and attributed string construction
- `com.quill.pipeline > MeasureHeight` -- height measurement passes

These signposts are available in any Debug or Release build and have negligible overhead when Instruments is not attached.

## Reproducing these benchmarks

All measurements in this document can be reproduced locally. The benchmark fixtures live in `Tests/QuillKitBenchmarks/` and can be run with:

```bash
swift test --filter QuillKitBenchmarks
```

To profile with Instruments, open `Examples/BasicIntegration/BasicIntegration.xcodeproj` in Xcode, build in Release configuration, and run with Product → Profile (⌘I). Select the **Points of Interest** template and look for the `com.quill.pipeline` signpost category.

### Device matters

These numbers are on iPhone 15 Pro Max. Expect roughly:

- **2-3x higher frame times** on iPhone 12 / iPhone SE 3rd gen.
- **Broadly similar behavior** on iPad Pro (M-series) — the parse + render pipeline is CPU-bound, not GPU-bound.
- **Frame drops** on older devices with very large streaming documents — the 16ms frame budget gets tighter.

Benchmark reports from other devices are welcome via PR (update the "Device coverage" table at the bottom of this document).

## Caveats

- Benchmarks were run on a specific device (iPhone 15 Pro Max) with a specific OS version (iOS 26.4) in Release configuration. Older devices, debug builds, or different content will produce different numbers.
- Parse time scales with document complexity. The 7.53ms max parse was measured on a 10KB+ document with mixed content types. Simpler documents parse faster.
- Streaming render time depends on tail complexity. Most ticks render simple text; ticks that close a code block or table attachment are more expensive.
- Memory measurements use All Heap & Anonymous VM (Persistent) in Instruments. Transient allocations during rendering are not captured in the post-idle numbers.

## Device coverage

Benchmarks on devices other than the reference device, contributed via PR.

| Device | iOS | Static render max | Streaming render avg | Dropped frames | Contributor | Date |
|--------|-----|-------------------|----------------------|----------------|-------------|------|
| iPhone 15 Pro Max (reference) | 26.4 | ~870us | 1.43ms | 0 / 2,552 | maintainer | 2026-04-11 |
| _(awaiting contributions)_ | | | | | | |
