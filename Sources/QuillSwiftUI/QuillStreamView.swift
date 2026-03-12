import QuillKit
import SwiftUI

/// Streaming markdown view backed by QuillView and driven by an AsyncSequence.
public struct QuillStreamView<S: AsyncSequence & Sendable>: UIViewRepresentable
    where S.Element == String
{
    let chunks: S
    let mode: StreamingMode
    let onError: (@Sendable (Error) -> Void)?
    let preset: QuillStreamingPreset

    public init(
        chunks: S,
        preset: QuillStreamingPreset = .balanced,
        mode: StreamingMode = .bufferedModules,
        onError: (@Sendable (Error) -> Void)? = nil
    ) {
        self.chunks = chunks
        self.mode = mode
        self.onError = onError
        self.preset = preset
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(preset: preset, mode: mode)
    }

    public func makeUIView(context: Context) -> QuillView {
        let coordinator = context.coordinator
        coordinator.subscribe(to: chunks, onError: onError)
        return coordinator.quillView
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: QuillView,
        context: Context
    ) -> CGSize? {
        fittedSize(for: uiView, proposal: proposal)
    }

    public func updateUIView(_ uiView: QuillView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.quillView.streamingPreset != preset {
            coordinator.quillView.streamingPreset = preset
        }
        if coordinator.quillView.streamingMode != mode {
            coordinator.quillView.streamingMode = mode
        }
    }

    public static func dismantleUIView(_ uiView: QuillView, coordinator: Coordinator) {
        coordinator.cancel()
    }
}

public extension QuillStreamView {
    @MainActor
    final class Coordinator {
        let quillView: QuillView
        private var generation = 0
        private var subscriptionTask: Task<Void, Never>?

        init(preset: QuillStreamingPreset, mode: StreamingMode) {
            self.quillView = QuillView(streamingPreset: preset)
            self.quillView.streamingMode = mode
            self.quillView.onHeightChange = { [weak quillView] _, _ in
                quillView?.invalidateIntrinsicContentSize()
            }
        }

        func cancel() {
            subscriptionTask?.cancel()
            subscriptionTask = nil
            quillView.cancelStreaming()
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
