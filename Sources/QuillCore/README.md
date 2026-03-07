# QuillCore

Platform-agnostic markdown parsing and AST types.

## Purpose

QuillCore provides the foundation layer of swift-quill. It parses markdown input into a structured AST (`RenderElement` array) that downstream renderers consume. All types are pure value types with zero UIKit or AppKit dependencies.

## Dependencies

- [swift-markdown](https://github.com/swiftlang/swift-markdown) (fully encapsulated -- consumers never see the Markdown module)

## Testing

QuillCore is testable via `swift test` on the command line without requiring a simulator, satisfying the ARCH-01 requirement that the core parsing layer remains platform-agnostic.

```bash
swift test --filter QuillCoreTests
```
