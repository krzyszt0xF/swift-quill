# QuillCore

QuillCore is Quill's parsing and streaming engine. It exists to keep the package architecture layered, testable, and UIKit-free.

Most apps should not depend on QuillCore directly. Use:

| Need | Product |
|------|---------|
| UIKit rendering | [QuillKit](../QuillKit/README.md) |
| SwiftUI rendering | [QuillSwiftUI](../QuillSwiftUI/README.md) |

QuillCore sits at the front of the internal Markdown pipeline:

```text
Markdown -> Block AST -> FlowSegmentBuilder -> RenderTree -> Renderer
```

It wraps swift-markdown, reduces streaming chunks into Quill's block model, and exposes only the internals needed by QuillKit. Rendering stays in QuillKit. QuillCore is not a consumer extension API and should not be treated as a plugin surface.

See the [root README](../../README.md) for installation and product-level usage.
