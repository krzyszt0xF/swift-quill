import Foundation
import QuillCore
import UIKit

@MainActor
final class StreamCoordinator {
    var hasActiveController: Bool { controller != nil }
    var hostView: DocumentTextView { renderer.textView }
    
    var onHeightInvalidated: (() -> Void)?
    var onLinkSelection: ((URL) -> Void)? {
        didSet { renderer.textView.onLinkSelection = onLinkSelection }
    }
    var syntaxHighlighter: (any SyntaxHighlighter)? {
        didSet { renderer.set(highlighter: syntaxHighlighter) }
    }

    private var appendTask: Task<Void, Never>?
    private let bufferedStreamCommitScheduler: BufferedStreamCommitScheduler
    private var controller: MarkdownStreamController?
    private var finishTask: Task<Void, Never>?
    private let makeStreamController: () -> MarkdownStreamController
    private let renderer: DocumentRenderer
    private var streamGeneration = 0
    private var streamTask: Task<Void, Never>?

    init(
        renderer: DocumentRenderer,
        bufferedStreamCommitScheduler: BufferedStreamCommitScheduler,
        streamController: @escaping () -> MarkdownStreamController
    ) {
        makeStreamController = streamController
        self.bufferedStreamCommitScheduler = bufferedStreamCommitScheduler
        self.renderer = renderer
    }

    deinit {
        appendTask?.cancel()
        finishTask?.cancel()
        streamTask?.cancel()
    }
}

extension StreamCoordinator {
    static var live: StreamCoordinator {
        StreamCoordinator(
            renderer: .live,
            bufferedStreamCommitScheduler: .live,
            streamController: MarkdownStreamController.init)
    }
}

extension StreamCoordinator {
    func append(
        _ chunk: String,
        currentMarkdown: String?,
        configuration: RenderConfiguration,
        needsRestart: Bool) {
        if needsRestart {
            startStream(bootstrap: currentMarkdown, configuration: configuration)
        }

        guard let streamController = controller else { return }

        if configuration.streamingMode == .bufferedModules {
            appendBufferedChunk(chunk, to: streamController)
        } else {
            enqueueAppendChunk(chunk, to: streamController)
        }
    }

    func applyConfiguration(_ configuration: RenderConfiguration) {
        bufferedStreamCommitScheduler.applyConfiguration(configuration)
    }

    func cancelStreaming() {
        cancelAllTasks()
        onHeightInvalidated?()
    }

    func finish(configuration: RenderConfiguration) {
        guard let streamController = controller else { return }

        controller = nil
        let task = streamTask
        let generation = streamGeneration
        let pendingAppendTask = appendTask
        appendTask = nil

        finishTask?.cancel()
        finishTask = Task { [weak self] in
            guard let self else { return }

            await pendingAppendTask?.value

            if configuration.streamingMode == .bufferedModules {
                let remaining = self.bufferedStreamCommitScheduler.flushRemaining()
                if !remaining.isEmpty {
                    await streamController.append(remaining)
                }
            }

            await streamController.finish()
            await task?.value
            guard self.streamGeneration == generation else { return }
            self.onHeightInvalidated?()
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
    func cancelAllTasks() {
        streamTask?.cancel()
        streamTask = nil
        finishTask?.cancel()
        finishTask = nil
        appendTask?.cancel()
        appendTask = nil
        bufferedStreamCommitScheduler.reset()
        controller = nil
        streamGeneration += 1
    }

    func startStream(bootstrap: String? = nil, configuration: RenderConfiguration) {
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

                BlockReducer.apply(event, to: &state)
                self.renderer.render(blocks: state.blocks, frozenCount: state.frozenCount)
                self.onHeightInvalidated?()
            }
        }
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
                self?.enqueueCommittedChunks(chunks, to: streamController)
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
                self?.enqueueCommittedChunks(chunks, to: streamController)
            },
            onFlushDue: { [weak self] nextGeneration in
                self?.flushBufferedChunks(generation: nextGeneration, to: streamController)
            }
        )
    }
}

// MARK: - Append Pipeline

private extension StreamCoordinator {
    func enqueueAppendChunk(
        _ chunk: String,
        to streamController: MarkdownStreamController
    ) {
        guard chunk.isEmpty == false else { return }

        let priorTask = appendTask
        appendTask = Task {
            await priorTask?.value
            guard !Task.isCancelled else { return }

            await streamController.append(chunk)
        }
    }

    func enqueueCommittedChunks(
        _ chunks: [String],
        to streamController: MarkdownStreamController
    ) {
        for chunk in chunks where chunk.isEmpty == false {
            enqueueAppendChunk(chunk, to: streamController)
        }
    }
}
