import QuillKit
import SwiftUI

/// Streaming markdown view backed by QuillView and driven by an AsyncSequence.
public struct QuillStreamView<S: AsyncSequence & Sendable>: UIViewRepresentable where S.Element == String {
    let chunks: S
    let configuration: QuillConfiguration
    let onError: (@Sendable (Error) -> Void)?
    let streamID: AnyHashable?

    public init(
        chunks: S,
        streamID: AnyHashable? = nil,
        configuration: QuillConfiguration = .default,
        onError: (@Sendable (Error) -> Void)? = nil
    ) {
        self.chunks = chunks
        self.configuration = configuration
        self.onError = onError
        self.streamID = streamID
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(configuration: configuration)
    }

    public func makeUIView(context: Context) -> QuillView {
        let coordinator = context.coordinator
        applyConfiguration(
            to: coordinator.quillView,
            imageLoader: context.environment.quillImageLoader,
            linkTapHandler: context.environment.quillLinkTapHandler,
            syntaxHighlighter: context.environment.quillSyntaxHighlighter
        )
        coordinator.setOnStreamFinished(context.environment.quillStreamFinishedHandler)
        coordinator.subscribe(to: chunks, streamID: streamID, onError: onError)

        return coordinator.quillView
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: QuillView,
        context: Context
    ) -> CGSize? {
        uiView.calculateFittedSize(for: proposal)
    }

    public func updateUIView(_ uiView: QuillView, context: Context) {
        applyConfiguration(
            to: context.coordinator.quillView,
            imageLoader: context.environment.quillImageLoader,
            linkTapHandler: context.environment.quillLinkTapHandler,
            syntaxHighlighter: context.environment.quillSyntaxHighlighter
        )
        context.coordinator.setOnStreamFinished(context.environment.quillStreamFinishedHandler)
        context.coordinator.subscribeIfNeeded(to: chunks, streamID: streamID, onError: onError)
    }

    public static func dismantleUIView(_ uiView: QuillView, coordinator: Coordinator) {
        coordinator.cancel()
    }
}

extension QuillStreamView {
    func applyConfiguration(
        to view: QuillView,
        imageLoader: (any ImageLoading)? = nil,
        linkTapHandler: (@Sendable (URL) -> Void)? = nil,
        syntaxHighlighter: (any SyntaxHighlighting)? = nil
    ) {
        view.imageLoader = imageLoader
        view.onLinkSelection = linkTapHandler
        view.syntaxHighlighter = syntaxHighlighter
        view.configuration = configuration
    }
}

public extension QuillStreamView {
    @MainActor
    final class Coordinator {
        // Internal to block SwiftUI consumers from reaching into the underlying UIKit view and
        // bypassing the streamID-based lifecycle managed by subscribe(_:) / subscribeIfNeeded(_:).
        // Tests use `@testable import QuillSwiftUI` and continue to have access.
        internal let quillView: QuillView
        private var generation = 0
        private var subscribedStreamID: AnyHashable?
        private var subscriptionTask: Task<Void, Never>?

        init(configuration: QuillConfiguration) {
            quillView = QuillView(configuration: configuration)
            quillView.configureHeightInvalidation()
        }

        func cancel() {
            subscriptionTask?.cancel()
            subscriptionTask = nil
            subscribedStreamID = nil
            quillView.cancelStreaming()
        }

        func setOnStreamFinished(_ handler: (@MainActor @Sendable () -> Void)?) {
            quillView.onStreamFinished = handler
        }

        func subscribe(to chunks: S, onError: (@Sendable (Error) -> Void)?) {
            subscribe(to: chunks, streamID: nil, onError: onError)
        }

        internal func subscribeIfNeeded(
            to chunks: S,
            streamID: AnyHashable?,
            onError: (@Sendable (Error) -> Void)?
        ) {
            guard subscribedStreamID != streamID else { return }
            subscribe(to: chunks, streamID: streamID, onError: onError)
        }

        internal func subscribe(
            to chunks: S,
            streamID: AnyHashable?,
            onError: (@Sendable (Error) -> Void)?
        ) {
            cancel()
            generation += 1
            subscribedStreamID = streamID

            let currentGeneration = generation
            quillView.reset()

            subscriptionTask = Task { [weak self] in
                guard let self else { return }

                do {
                    for try await chunk in chunks {
                        guard !Task.isCancelled,
                              self.generation == currentGeneration
                        else { break }

                        self.quillView.append(chunk)
                    }

                    guard !Task.isCancelled,
                          self.generation == currentGeneration
                    else { return }

                    self.quillView.finish()
                } catch {
                    guard !Task.isCancelled,
                          self.generation == currentGeneration
                    else { return }

                    self.quillView.cancelStreaming()
                    onError?(error)
                }
            }
        }
    }
}
