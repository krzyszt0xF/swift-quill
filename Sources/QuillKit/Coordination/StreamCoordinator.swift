import Foundation
import QuillCore
import UIKit

@MainActor
final class StreamCoordinator {
    var onHeightInvalidated: (() -> Void)?

    var hasActiveController: Bool { controller != nil }
    var hostView: UIView { renderer.hostView }
    var onLinkTap: ((URL) -> Void)? {
        didSet {
            renderer.onLinkTap = onLinkTap
            renderer.rebindLinkTapHandlers()
        }
    }

    private(set) var renderedFrozenCount = 0

    private var appendTask: Task<Void, Never>?
    private var bufferingFlushTask: Task<Void, Never>?
    private var controller: MarkdownStreamController?
    private var finishTask: Task<Void, Never>?
    private let makeStreamController: () -> MarkdownStreamController
    private var moduleStreamGate: ModuleStreamGate
    private let now: () -> TimeInterval
    private let renderer: StreamingBlockRenderer
    private let sequencer: RevealSequencer
    private let sleep: (Duration) async -> Void
    private var streamGeneration = 0
    private var streamTask: Task<Void, Never>?
    
    init(
        renderer: StreamingBlockRenderer,
        sequencer: RevealSequencer,
        moduleStreamGate: ModuleStreamGate,
        now: @escaping () -> TimeInterval,
        sleep: @escaping (Duration) async -> Void,
        streamController: @escaping () -> MarkdownStreamController) {
            makeStreamController = streamController
            self.moduleStreamGate = moduleStreamGate
            self.now = now
            self.renderer = renderer
            self.sequencer = sequencer
            self.sleep = sleep
            bindLayoutCallbacks()
        }
    
    deinit {
        appendTask?.cancel()
        bufferingFlushTask?.cancel()
        finishTask?.cancel()
        streamTask?.cancel()
    }
}

extension StreamCoordinator {
    static var live: StreamCoordinator {
        StreamCoordinator(
            renderer: .live,
            sequencer: .live,
            moduleStreamGate: .init(),
            now: { Date.timeIntervalSinceReferenceDate },
            sleep: { duration in
                try? await Task.sleep(for: duration)
            },
            streamController: MarkdownStreamController.init
        )
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
            appendBufferedChunk(chunk, to: streamController, configuration: configuration)
        } else {
            enqueueAppendChunk(chunk, to: streamController)
        }
    }

    func applyConfiguration(_ configuration: RenderConfiguration) {
        moduleStreamGate.updateConfiguration(
            ModuleStreamGateConfiguration(
                minModuleLength: configuration.bufferedStream.minModuleLength,
                maxBufferingDelay: configuration.bufferedStream.maxBufferingDelay
            )
        )
        sequencer.applyConfiguration(typewriter: configuration.typewriter, performanceProfile: configuration.performanceProfile)
        sequencer.setFixedTiming(configuration.streamingMode == .bufferedModules ? .buffered : nil)
        sequencer.setMinimumTextAnimationWindow( configuration.streamingMode == .bufferedModules ? 0.4 : 0)

        if configuration.streamingMode != .bufferedModules {
            cancelBufferedFlush()
            moduleStreamGate.reset()
        }
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
                self.cancelBufferedFlush()
                let remaining = self.moduleStreamGate.flushRemaining()
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

    func renderStatic(blocks: [Block]) {
        reset()
        renderer.update(blocks: blocks, frozenCount: blocks.count)
    }

    func reset() {
        cancelAllTasks()
        renderer.reset()
        renderedFrozenCount = 0
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
        cancelBufferedFlush()
        moduleStreamGate.reset()
        controller = nil
        streamGeneration += 1
        sequencer.reset()
    }

    func bindLayoutCallbacks() {
        sequencer.onLayoutChange = { [weak self] view in
            if let self, let view {
                self.renderer.containerView.invalidateBlockLayout(for: view)
            }
            self?.onHeightInvalidated?()
        }
        sequencer.onComplete = { [weak self] in
            self?.onHeightInvalidated?()
        }
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
                let newFrozen = state.frozenCount

                if newFrozen > self.renderedFrozenCount {
                    let newBlocks = Array(state.blocks[self.renderedFrozenCount..<newFrozen])

                    self.renderedFrozenCount = newFrozen

                    let views = self.renderer.append(blocks: newBlocks)
                    for view in views {
                        self.sequencer.enqueue(view: view)
                    }
                    self.onHeightInvalidated?()
                }
            }
        }
    }
}

// MARK: - Buffered Streaming

private extension StreamCoordinator {
    func appendBufferedChunk(
        _ chunk: String,
        to streamController: MarkdownStreamController,
        configuration: RenderConfiguration
    ) {
        let currentTime = now()
        let result = moduleStreamGate.append(
            chunk,
            now: currentTime
        )

        enqueueCommittedChunks(result.committedChunks, to: streamController)

        if result.hasPendingText {
            scheduleBufferedFlushIfNeeded(
                streamController: streamController,
                now: currentTime,
                configuration: configuration
            )
        } else {
            cancelBufferedFlush()
        }
    }

    func cancelBufferedFlush() {
        bufferingFlushTask?.cancel()
        bufferingFlushTask = nil
    }

    func flushBufferedInputIfNeeded(
        streamController: MarkdownStreamController,
        configuration: RenderConfiguration
    ) {
        let currentTime = now()
        let chunks = moduleStreamGate.commitIfOverdue(now: currentTime)
        enqueueCommittedChunks(chunks, to: streamController)

        if moduleStreamGate.hasPendingText {
            scheduleBufferedFlushIfNeeded(
                streamController: streamController,
                now: currentTime,
                configuration: configuration
            )
        } else {
            cancelBufferedFlush()
        }
    }

    func scheduleBufferedFlushIfNeeded(
        streamController: MarkdownStreamController,
        now: TimeInterval,
        configuration: RenderConfiguration
    ) {
        cancelBufferedFlush()
        let generation = streamGeneration
        let delay = moduleStreamGate.timeUntilForcedCommit(now: now) ?? 0.12
        let effectiveDelay = max(0.05, delay)

        bufferingFlushTask = Task { [weak self] in
            guard let self else { return }
            await self.sleep(.seconds(effectiveDelay))
            guard !Task.isCancelled, self.streamGeneration == generation else { return }
            self.flushBufferedInputIfNeeded(
                streamController: streamController,
                configuration: configuration
            )
        }
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
