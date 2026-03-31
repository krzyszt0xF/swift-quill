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

    private let bufferedStreamCommitScheduler: BufferedStreamCommitScheduler
    private let bufferedVisualFeeder: BufferedVisualFeeder
    private var controller: MarkdownStreamController?
    private var finishTask: Task<Void, Never>?
    private var lastTailRevealHeightInvalidation = 0.0
    private let makeStreamController: () -> MarkdownStreamController
    private var renderConfiguration: RenderConfiguration
    private let renderer: DocumentRenderer
    private var streamGeneration = 0
    private var streamTask: Task<Void, Never>?

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
                    self.bufferedVisualFeeder.enqueueBufferedModules(
                        [remaining],
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
        reset()
        renderer.render(blocks: blocks, frozenCount: blocks.count)
    }

    func reset() {
        cancelAllTasks()
        renderer.reset()
    }
}

// MARK: - Task Management

private extension StreamCoordinator {
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

    func applyStreamingSnapshot(_ snapshot: StreamingSnapshot) {
        let outcome = renderer.render(
            blocks: snapshot.blocks,
            frozenCount: snapshot.frozenCount
        )

        guard outcome.invalidatedHeight else { return }
        invalidateHeight(for: .rendererSnapshotApplied)
    }

    func cancelAllTasks() {
        lastTailRevealHeightInvalidation = 0
        renderer.cancelStreaming()
        bufferedVisualFeeder.cancel()
        streamTask?.cancel()
        streamTask = nil
        finishTask?.cancel()
        finishTask = nil
        bufferedStreamCommitScheduler.reset()
        controller = nil
        streamGeneration += 1
    }

    func handleParserEvent(
        _ event: ParserEvent,
        state: inout BlockReducer.ReducerState
    ) {
        BlockReducer.apply(event, to: &state)

        let snapshot = StreamingSnapshot(
            blocks: state.blocks,
            frozenCount: state.frozenCount
        )
        applyStreamingSnapshot(snapshot)
    }

    func invalidateHeight(for reason: HeightInvalidationReason) {
        switch reason {
        case .rendererSnapshotApplied, .streamFinished, .streamReset:
            lastTailRevealHeightInvalidation = Date.timeIntervalSinceReferenceDate
            onHeightInvalidated?()
        case .tailRevealProgress:
            let now = Date.timeIntervalSinceReferenceDate
            let minimumInterval = max(
                0.04,
                renderConfiguration.layout.heightMeasurementCoalescingInterval * 2
            )
            guard now - lastTailRevealHeightInvalidation >= minimumInterval else { return }

            lastTailRevealHeightInvalidation = now
            onHeightInvalidated?()
        }
    }

    func startStream(bootstrap: String? = nil) {
        cancelStreaming()

        let streamController = makeStreamController()
        controller = streamController

        let generation = streamGeneration
        streamTask = Task { [weak self] in
            var state = BlockReducer.ReducerState()
            let events = await streamController.events()

            if let bootstrap, !bootstrap.isEmpty {
                await streamController.append(bootstrap)
            }

            for await event in events {
                guard !Task.isCancelled, let self, self.streamGeneration == generation else { break }

                self.handleParserEvent(event, state: &state)
            }
        }
    }

    func startStreamIfNeeded(currentMarkdown: String?, needsRestart: Bool) {
        guard needsRestart else { return }
        startStream(bootstrap: currentMarkdown)
    }

    func syncConfiguration(_ configuration: RenderConfiguration) {
        renderConfiguration = configuration
        bufferedStreamCommitScheduler.applyConfiguration(configuration)
        renderer.applyTailRevealPolicy(configuration.tailReveal)
    }
}

// MARK: - Buffered Streaming

private extension StreamCoordinator {
    func appendBufferedChunk(
        _ chunk: String,
        to streamController: MarkdownStreamController
    ) {
        bufferedStreamCommitScheduler.append(
            chunk,
            generation: streamGeneration,
            commitChunks: { [weak self] chunks in
                guard let self else { return }
                self.bufferedVisualFeeder.enqueueBufferedModules(
                    chunks,
                    policy: self.renderConfiguration.tailReveal,
                    to: streamController
                )
            },
            onFlushDue: { [weak self] generation in
                self?.flushBufferedChunks(generation: generation, to: streamController)
            }
        )
    }

    func flushBufferedChunks(
        generation: Int,
        to streamController: MarkdownStreamController
    ) {
        guard streamGeneration == generation else { return }

        bufferedStreamCommitScheduler.flushIfNeeded(
            generation: generation,
            commitChunks: { [weak self] chunks in
                guard let self else { return }
                self.bufferedVisualFeeder.enqueueBufferedModules(
                    chunks,
                    policy: self.renderConfiguration.tailReveal,
                    to: streamController
                )
            },
            onFlushDue: { [weak self] nextGeneration in
                self?.flushBufferedChunks(generation: nextGeneration, to: streamController)
            }
        )
    }

    func routeIncomingChunk(
        _ chunk: String,
        to streamController: MarkdownStreamController
    ) {
        if renderConfiguration.streamingMode == .bufferedModules {
            appendBufferedChunk(chunk, to: streamController)
            return
        }

        enqueueAppendChunk(chunk, to: streamController)
    }

    func enqueueAppendChunk(
        _ chunk: String,
        to streamController: MarkdownStreamController
    ) {
        bufferedVisualFeeder.enqueueImmediateChunk(
            chunk,
            policy: renderConfiguration.tailReveal,
            to: streamController
        )
    }
}
