import QuillKit
import SwiftUI

// MARK: - View Access

extension View {
    /// Provides access to Quill-specific modifiers.
    @inlinable public var quill: QuillNamespace<Self> { .init(self) }
}

// MARK: - Environment Keys

private struct ImageLoaderKey: EnvironmentKey {
    static let defaultValue: (any ImageLoading)? = nil
}

private struct LinkTapHandlerKey: EnvironmentKey {
    static let defaultValue: (@Sendable (URL) -> Void)? = nil
}

private struct StreamFinishedHandlerKey: EnvironmentKey {
    static let defaultValue: (@MainActor @Sendable () -> Void)? = nil
}

private struct SyntaxHighlighterKey: EnvironmentKey {
    static let defaultValue: (any SyntaxHighlighting)? = nil
}

// MARK: - Environment Values

extension EnvironmentValues {
    var quillImageLoader: (any ImageLoading)? {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }

    var quillLinkTapHandler: (@Sendable (URL) -> Void)? {
        get { self[LinkTapHandlerKey.self] }
        set { self[LinkTapHandlerKey.self] = newValue }
    }

    var quillStreamFinishedHandler: (@MainActor @Sendable () -> Void)? {
        get { self[StreamFinishedHandlerKey.self] }
        set { self[StreamFinishedHandlerKey.self] = newValue }
    }

    var quillSyntaxHighlighter: (any SyntaxHighlighting)? {
        get { self[SyntaxHighlighterKey.self] }
        set { self[SyntaxHighlighterKey.self] = newValue }
    }
}

// MARK: - Namespace Modifiers

public extension QuillNamespace where Base: View {
    func onLinkTap(_ handler: @escaping @Sendable (URL) -> Void) -> some View {
        base.environment(\.quillLinkTapHandler, handler)
    }

    func onStreamFinished(_ handler: @escaping @MainActor @Sendable () -> Void) -> some View {
        base.environment(\.quillStreamFinishedHandler, handler)
    }

    func setHighlighter(_ highlighter: (any SyntaxHighlighting)?) -> some View {
        base.environment(\.quillSyntaxHighlighter, highlighter)
    }

    func setImageLoader(_ imageLoader: (any ImageLoading)?) -> some View {
        base.environment(\.quillImageLoader, imageLoader)
    }
}
