# QuillCore

Platform-agnostic markdown parsing and streaming infrastructure.

## Purpose

QuillCore provides the foundation layer of swift-quill. It parses markdown input into a structured Block AST that downstream renderers consume. All types are package-scoped and have zero UIKit or AppKit dependencies.

## Key Types

- `Block` / `Inline` -- Recursive AST representing parsed markdown
- `MarkdownParser` -- Converts raw markdown strings to `[Block]`
- `MarkdownStreamController` -- Actor-based streaming coordinator for chunk-at-a-time input
- `BlockReducer` -- Reduces parser events into an incrementally-updated block array

## Dependencies

- [swift-markdown](https://github.com/swiftlang/swift-markdown) (fully encapsulated -- consumers never see the Markdown module)

## Testing

QuillCore is testable via `swift test` on the command line without requiring a simulator:

```bash
swift test --filter QuillCoreTests
```
