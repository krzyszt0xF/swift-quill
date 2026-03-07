import QuillCore

/// QuillKit provides UIKit rendering infrastructure.
/// In Phase 1 this is a stub proving the dependency chain.
public enum QuillKit: Sendable {
    /// Library version, delegates to QuillCore.
    public static var coreVersion: String { QuillCore.version }
}
