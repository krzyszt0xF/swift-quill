# Rich Content Rendering Benchmark

This document exercises the expensive structural block rendering paths: code blocks with syntax highlighting, GFM pipe tables, and image elements.

## Code Block: Swift Actor Implementation

The following Swift example demonstrates a streaming pipeline actor with structured concurrency and cancellation support:

```swift
actor StreamPipeline {
    private var buffer: [String] = []
    private var state: PipelineState = .idle
    private var cancelContinuation: CheckedContinuation<Void, Never>?

    enum PipelineState {
        case idle
        case streaming(generation: Int)
        case finishing
        case cancelled
    }

    func append(_ chunk: String) async throws {
        guard case .streaming = state else {
            throw PipelineError.notStreaming
        }
        buffer.append(chunk)
        await processBuffer()
    }

    func start() {
        let generation = Int.random(in: 0..<Int.max)
        state = .streaming(generation: generation)
        buffer.removeAll()
    }

    func cancel() {
        state = .cancelled
        buffer.removeAll()
        cancelContinuation?.resume()
        cancelContinuation = nil
    }

    private func processBuffer() async {
        while !buffer.isEmpty {
            let chunk = buffer.removeFirst()
            await MainActor.run {
                renderChunk(chunk)
            }
        }
    }
}
```

The actor boundary ensures that buffer mutations are serialized without manual locking. The `processBuffer` method drains the buffer one chunk at a time, applying each to the renderer on the main actor.

## Code Block: Python Data Processing

A Python example showing a common data processing pipeline with type hints and error handling:

```python
from dataclasses import dataclass
from typing import AsyncIterator, Optional
import asyncio
import json

@dataclass
class ChunkMetrics:
    chunk_index: int
    byte_count: int
    parse_duration_ms: float
    render_duration_ms: float
    cumulative_bytes: int

class StreamProcessor:
    def __init__(self, max_buffer_size: int = 1024):
        self._buffer: list[str] = []
        self._metrics: list[ChunkMetrics] = []
        self._max_buffer_size = max_buffer_size
        self._total_bytes = 0
        self._chunk_count = 0

    async def process_stream(
        self, chunks: AsyncIterator[str]
    ) -> list[ChunkMetrics]:
        async for chunk in chunks:
            self._chunk_count += 1
            self._total_bytes += len(chunk.encode("utf-8"))
            self._buffer.append(chunk)

            if self._should_flush():
                await self._flush_buffer()

        if self._buffer:
            await self._flush_buffer()

        return self._metrics

    def _should_flush(self) -> bool:
        total = sum(len(c) for c in self._buffer)
        return total >= self._max_buffer_size

    async def _flush_buffer(self) -> None:
        combined = "".join(self._buffer)
        self._buffer.clear()
        metric = await self._process_combined(combined)
        self._metrics.append(metric)
```

## Code Block: JSON Configuration Schema

A detailed JSON configuration example with nested objects and arrays:

```json
{
  "pipeline": {
    "version": "2.0",
    "stages": [
      {
        "name": "parse",
        "isolation": "background",
        "timeout_ms": 5000,
        "options": {
          "parser": "swift-markdown",
          "extensions": ["gfm", "strikethrough", "task-lists"],
          "max_document_size_bytes": 1048576
        }
      },
      {
        "name": "reduce",
        "isolation": "main-actor",
        "timeout_ms": 2000,
        "options": {
          "frozen_prefix_tracking": true,
          "tail_preview_enabled": true,
          "max_blocks_per_snapshot": 500
        }
      },
      {
        "name": "render",
        "isolation": "main-actor",
        "timeout_ms": 16,
        "options": {
          "fragment_caching": true,
          "tail_only_mutations": true,
          "batch_edit_transactions": true,
          "max_provider_recycling_depth": 10
        }
      },
      {
        "name": "enrich",
        "isolation": "background",
        "timeout_ms": 30000,
        "options": {
          "syntax_highlighting": {
            "enabled": true,
            "theme": "atom-one-dark",
            "max_concurrent_requests": 3
          },
          "image_loading": {
            "enabled": true,
            "cache_policy": "memory-and-disk",
            "retry_count": 2,
            "placeholder_aspect_ratio": 1.5
          }
        }
      }
    ],
    "buffering": {
      "min_module_length": 50,
      "max_buffering_delay_seconds": 1.5,
      "structure_hold_types": ["code_block", "table"]
    }
  }
}
```

## Table: Pipeline Stage Performance Metrics

Performance measurements across pipeline stages for the benchmark corpus:

| Stage | Fixture | p50 (ms) | p95 (ms) | p99 (ms) | Max (ms) | Iterations |
|:------|:--------|:---------|:---------|:---------|:---------|:-----------|
| Parse | mixed-10kb | 0.42 | 0.58 | 0.71 | 0.89 | 100 |
| Parse | prose-long | 0.31 | 0.44 | 0.52 | 0.67 | 100 |
| Parse | structure-heavy | 0.28 | 0.39 | 0.48 | 0.61 | 100 |
| Parse | rich-content | 0.38 | 0.51 | 0.63 | 0.82 | 100 |
| Reduce | mixed-10kb | 0.15 | 0.22 | 0.28 | 0.35 | 100 |
| Reduce | prose-long | 0.11 | 0.16 | 0.21 | 0.27 | 100 |
| Render | mixed-10kb | 2.31 | 3.18 | 4.05 | 5.12 | 50 |
| Render | rich-content | 3.45 | 4.72 | 5.88 | 7.21 | 50 |

## Table: Configuration Parameters and Defaults

| Parameter | Type | Default | Range | Unit | Description |
|:----------|:-----|:--------|:------|:-----|:------------|
| `minModuleLength` | `Int` | 50 | 1-500 | chars | Minimum buffer size before commit |
| `maxBufferingDelay` | `Double` | 1.5 | 0.1-10.0 | seconds | Maximum time before forced commit |
| `heightCoalescingInterval` | `Double` | 0.05 | 0.0-1.0 | seconds | Debounce interval for height measurement |
| `heightMinDelta` | `Double` | 0.5 | 0.0-10.0 | points | Minimum height change to notify |

## Image References

Diagrams illustrating the rendering pipeline architecture and data flow:

![Pipeline overview showing parse, reduce, render, and enrich stages with isolation boundaries](https://example.com/diagrams/pipeline-overview.png)

The pipeline overview diagram shows the four main stages and their isolation contexts. Parse runs on a background actor, reduce and render on the main actor, and enrichment tasks on background threads.

![Streaming sequence diagram showing chunk arrival, buffer commit, and render application](https://example.com/diagrams/streaming-sequence.png)

The streaming sequence diagram traces a single chunk from arrival through buffer commit to final render application, highlighting the actor boundary crossings and task ownership transfers.

![Height measurement flow showing coalescing, measurement, and notification phases](https://example.com/diagrams/height-measurement-flow.png)

The height measurement diagram shows how the `HeightCoordinator` coalesces rapid invalidation requests into a single measurement pass, avoiding redundant layout work during streaming.

## Inline Code and Links

The rendering pipeline uses `NSTextContentStorage` for content management and `NSTextLayoutManager` for viewport-based layout. Key types include `DocumentRenderer` for block-to-attributed-string conversion, `StreamCoordinator` for pipeline orchestration, and `HeightCoordinator` for debounced height measurement.

For more information, see the [TextKit 2 documentation](https://developer.apple.com/documentation/uikit/textkit), the [swift-markdown parser](https://github.com/swiftlang/swift-markdown), and the [HighlighterSwift library](https://github.com/smittytone/HighlighterSwift) used for syntax highlighting.

Configuration is managed through `QuillConfiguration` which bundles theme, layout, rendering, and enrichment settings into a single `Sendable` struct.
