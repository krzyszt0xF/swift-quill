# QuillKit

UIKit rendering infrastructure for swift-quill.

## Purpose

QuillKit provides the UIKit rendering layer built on TextKit 2 with a per-block architecture. Each block-level markdown element is rendered as its own text view, enabling efficient incremental updates during streaming.

## Dependencies

- **QuillCore** -- Consumes the RenderElement AST produced by the parser
