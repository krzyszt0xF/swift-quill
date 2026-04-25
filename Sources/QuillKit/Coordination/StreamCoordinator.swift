import Foundation
import QuillCore
import UIKit

@MainActor
final class StreamCoordinator {
    var hasActiveController: Bool { controller != nil }
    var hostView: DocumentTextView { renderer.textView }

    var onHeightInvalidated: (() -> Void)?
    var onStreamFinished: (() -> Void)?
    var onLinkSelection: ((URL) -> Void)? {
        didSet { renderer.textView.onLinkSelection = onLinkSelection }
    }
    var imageLoader: (any ImageLoading)? {
        didSet { renderer.set(imageLoader: imageLoader) }
    }
    var syntaxHighlighter: (any SyntaxHighlighting)? {
        didSet { renderer.set(highlighter: syntaxHighlighter) }
    }

    let bufferedStreamCommitScheduler: BufferedStreamCommitScheduler
    let bufferedVisualFeeder: BufferedVisualFeeder
    var controller: MarkdownStreamController?
    var finishTask: Task<Void, Never>?
    var lastTailRevealHeightInvalidation = 0.0
    let makeStreamController: () -> MarkdownStreamController
    var renderConfiguration: RenderConfiguration
    let renderer: DocumentRenderer
    var streamGeneration = 0
    var streamTask: Task<Void, Never>?

    init(
        renderer: DocumentRenderer,
        renderConfiguration: RenderConfiguration,
        bufferedStreamCommitScheduler: BufferedStreamCommitScheduler,
        bufferedVisualFeeder: BufferedVisualFeeder,
        streamController: @escaping () -> MarkdownStreamController
    ) {
        makeStreamController = streamController
        self.bufferedStreamCommitScheduler = bufferedStreamCommitScheduler
        self.bufferedVisualFeeder = bufferedVisualFeeder
        self.renderer = renderer
        self.renderConfiguration = renderConfiguration
        self.renderer.onTailRevealProgress = { [weak self] in
            self?.invalidateHeight(for: .tailRevealProgress)
        }
        self.renderer.onImageAspectRatioChanged = { [weak self] in
            self?.invalidateHeight(for: .imageAspectRatioUpdated)
        }
    }
}

extension StreamCoordinator {
    static var live: StreamCoordinator {
        StreamCoordinator(
            renderer: .live,
            renderConfiguration: .init(preset: .balanced),
            bufferedStreamCommitScheduler: .live,
            bufferedVisualFeeder: .init(),
            streamController: MarkdownStreamController.init)
    }
}

extension StreamCoordinator {
    func apply(configuration: QuillConfiguration) {
        renderer.apply(configuration: configuration)
        syncConfiguration(configuration.renderConfiguration)
    }

    func append(
        _ chunk: String,
        currentMarkdown: String?,
        configuration: QuillConfiguration,
        needsRestart: Bool
    ) {
        startStreamIfNeeded(
            currentMarkdown: currentMarkdown,
            configuration: configuration,
            needsRestart: needsRestart
        )

        guard let streamController = controller else { return }
        routeIncomingChunk(chunk, to: streamController)
    }

    func cancelStreaming() {
        // Cancellation is a hard stop: cancel active work and discard any pending buffered tail.
        cancelAllTasks()
        renderer.updateSelectionGate(isStreaming: false)
        invalidateHeight(for: .streamReset)
    }

    func finish(configuration: QuillConfiguration) {
        guard let streamController = controller else { return }
        syncConfiguration(configuration.renderConfiguration)

        controller = nil
        let task = streamTask
        let generation = streamGeneration
        let renderConfiguration = self.renderConfiguration

        finishTask?.cancel()
        finishTask = Task { [weak self] in
            guard let self else { return }

            if renderConfiguration.streamingMode == .bufferedModules {
                // Normal completion is the only path that promotes buffered remainder into the final render.
                let remaining = self.bufferedStreamCommitScheduler.flushRemaining()
                if !remaining.isEmpty {
                    self.bufferedVisualFeeder.enqueue(
                        bufferedModules: [remaining],
                        policy: renderConfiguration.tailReveal,
                        to: streamController
                    )
                }
            }

            await self.bufferedVisualFeeder.waitUntilDrained()
            await streamController.finish()
            await task?.value
            guard self.streamGeneration == generation else { return }
            self.renderer.updateSelectionGate(isStreaming: false)
            self.invalidateHeight(for: .streamFinished)
            self.onStreamFinished?()
        }
    }

    func renderStatic(
        blocks: [BlockNode],
        configuration: QuillConfiguration
    ) {
        cancelActiveWork()
        apply(configuration: configuration)
        renderer.updateSelectionGate(isStreaming: false)
        let outcome = renderer.render(blocks: blocks, frozenCount: blocks.count)
        guard outcome.invalidatedHeight else { return }

        invalidateHeight(for: .rendererSnapshotApplied)
    }

    func reset() {
        cancelActiveWork()
        renderer.textView.selectedRange = NSRange(location: 0, length: 0)
        renderer.reset()
        renderer.updateSelectionGate(isStreaming: false)
    }
}

extension StreamCoordinator {
    enum HeightInvalidationReason {
        case imageAspectRatioUpdated
        case rendererSnapshotApplied
        case streamFinished
        case streamReset
        case tailRevealProgress
    }

    struct StreamingSnapshot {
        let blocks: [BlockNode]
        let frozenCount: Int
    }
}
