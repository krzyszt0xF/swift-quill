import Foundation

/// Namespace for Quill-specific view modifiers.
public struct QuillNamespace<Base> {
    @usableFromInline let base: Base
    @inlinable public init(_ base: Base) { self.base = base }
}

extension QuillNamespace: Sendable where Base: Sendable {}
