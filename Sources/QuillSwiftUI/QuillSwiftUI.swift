import QuillKit

/// QuillSwiftUI provides SwiftUI wrappers around QuillKit.
/// In Phase 1 this is a stub proving the dependency chain.
public enum QuillSwiftUI: Sendable {
    /// Library version, delegates to QuillKit.
    public static var kitVersion: String { QuillKit.coreVersion }
}
