# QuillSwiftUI

Minimal SwiftUI target for swift-quill.

## Status

This target is intentionally minimal. It exists to establish the dependency chain (`QuillSwiftUI -> QuillKit -> QuillCore`) but does not yet provide a production SwiftUI wrapper. Real wrapper work is deferred to a future phase.

## Dependencies

- **QuillKit** -- Will wrap the UIKit rendering layer via `UIViewRepresentable`
