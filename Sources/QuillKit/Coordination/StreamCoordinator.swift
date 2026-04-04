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
    func applyConfiguration(_ configuration: RenderConfiguration) {
        syncConfiguration(configuration)
    }

    func append(
        _ chunk: String,
        currentMarkdown: String?,
        configuration: RenderConfiguration,
        needsRestart: Bool
    ) {
        syncConfiguration(configuration)
        startStreamIfNeeded(currentMarkdown: currentMarkdown, needsRestart: needsRestart)

        guard let streamController = controller else { return }
        routeIncomingChunk(chunk, to: streamController)
    }

    func cancelStreaming() {
        cancelAllTasks()
        invalidateHeight(for: .streamReset)
    }

    func finish(configuration: RenderConfiguration) {
        guard let streamController = controller else { return }
        syncConfiguration(configuration)

        controller = nil
        let task = streamTask
        let generation = streamGeneration
        let renderConfiguration = self.renderConfiguration

        finishTask?.cancel()
        finishTask = Task { [weak self] in
            guard let self else { return }

            if renderConfiguration.streamingMode == .bufferedModules {
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
            self.invalidateHeight(for: .streamFinished)
            self.onStreamFinished?()
        }
    }

    func renderStatic(blocks: [BlockNode]) {
        cancelActiveWork()
        let outcome = renderer.render(blocks: blocks, frozenCount: blocks.count)
        guard outcome.invalidatedHeight else { return }

        invalidateHeight(for: .rendererSnapshotApplied)
    }

    func reset() {
        cancelActiveWork()
        renderer.reset()
    }
}

extension StreamCoordinator {
    enum HeightInvalidationReason {
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
