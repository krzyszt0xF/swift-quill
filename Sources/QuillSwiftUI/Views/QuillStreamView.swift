import QuillKit
import SwiftUI

/// Streaming markdown view backed by QuillView and driven by an AsyncSequence.
public struct QuillStreamView<S: AsyncSequence & Sendable>: UIViewRepresentable where S.Element == String {
    let chunks: S
    let linkTapHandler: ((URL) -> Void)?
    let mode: StreamingMode
    let onFinished: (@MainActor () -> Void)?
    let onError: (@Sendable (Error) -> Void)?
    let preset: QuillStreamingPreset

    public init(
        chunks: S,
        mode: StreamingMode = .smoothedTail,
        onFinished: (@MainActor () -> Void)? = nil,
        onError: (@Sendable (Error) -> Void)? = nil,
        preset: QuillStreamingPreset = .balanced) {
            self.init(
                chunks: chunks,
                linkTapHandler: nil,
                mode: mode,
                onFinished: onFinished,
                onError: onError,
                preset: preset)
        }
    
    private init(
        chunks: S,
        linkTapHandler: ((URL) -> Void)?,
        mode: StreamingMode,
        onFinished: (@MainActor () -> Void)?,
        onError: (@Sendable (Error) -> Void)?,
        preset: QuillStreamingPreset
    ) {
        self.chunks = chunks
        self.linkTapHandler = linkTapHandler
        self.mode = mode
        self.onFinished = onFinished
        self.onError = onError
        self.preset = preset
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(preset: preset, mode: mode)
    }

    public func makeUIView(context: Context) -> QuillView {
        let coordinator = context.coordinator
        applyConfiguration(
            to: coordinator.quillView,
            syntaxHighlighter: context.environment.quillSyntaxHighlighter
        )
        coordinator.setOnStreamFinished(onFinished)
        coordinator.subscribe(to: chunks, onError: onError)
        
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
            syntaxHighlighter: context.environment.quillSyntaxHighlighter
        )
        context.coordinator.setOnStreamFinished(onFinished)
    }

    public static func dismantleUIView(_ uiView: QuillView, coordinator: Coordinator) {
        coordinator.cancel()
    }
}

public extension QuillStreamView {
    func onQuillLinkTap(_ handler: @escaping (URL) -> Void) -> Self {
        Self(
            chunks: chunks,
            linkTapHandler: handler,
            mode: mode,
            onFinished: onFinished,
            onError: onError,
            preset: preset
        )
    }

    func onQuillStreamFinished(_ handler: @escaping @MainActor () -> Void) -> Self {
        Self(
            chunks: chunks,
            linkTapHandler: linkTapHandler,
            mode: mode,
            onFinished: handler,
            onError: onError,
            preset: preset
        )
    }
}

extension QuillStreamView {
    func applyConfiguration(
        to view: QuillView,
        syntaxHighlighter: (any SyntaxHighlighting)? = nil
    ) {
        view.onLinkSelection = linkTapHandler
        view.syntaxHighlighter = syntaxHighlighter

        if view.streamingPreset != preset {
            view.streamingPreset = preset
        }

        if view.streamingMode != mode {
            view.streamingMode = mode
        }
    }
}

public extension QuillStreamView {
    @MainActor
    final class Coordinator {
        let quillView: QuillView
        private var generation = 0
        private var subscriptionTask: Task<Void, Never>?

        init(preset: QuillStreamingPreset, mode: StreamingMode) {
            quillView = QuillView(preset: preset)
            quillView.streamingMode = mode
            quillView.onHeightChange = { [weak quillView] _, _ in
                quillView?.invalidateIntrinsicContentSize()
            }
        }

        func cancel() {
            subscriptionTask?.cancel()
            subscriptionTask = nil
            quillView.cancelStreaming()
        }

        func setOnStreamFinished(_ handler: (@MainActor () -> Void)?) {
            quillView.onStreamFinished = handler
        }

        func subscribe(to chunks: S, onError: (@Sendable (Error) -> Void)?) {
            cancel()
            generation += 1
            
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
