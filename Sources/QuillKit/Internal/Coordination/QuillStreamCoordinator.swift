import QuillCore
import UIKit

@MainActor
final class QuillStreamCoordinator {
    var onHeightInvalidated: (() -> Void)?

    var hasActiveController: Bool { controller != nil }

    private(set) var renderedFrozenCount = 0

    private var appendTask: Task<Void, Never>?
    private var bufferingFlushTask: Task<Void, Never>?
    private var controller: MarkdownStreamController?
    private var finishTask: Task<Void, Never>?
    private var moduleStreamGate = ModuleStreamGate()
    private var pendingTailBlock: Block?
    private var streamGeneration = 0
    private var streamTask: Task<Void, Never>?
    private var tailUpdateTask: Task<Void, Never>?

    private let renderer: StreamingBlockRenderer
    private let sequencer: RevealSequencer

    init(renderer: StreamingBlockRenderer, sequencer: RevealSequencer) {
        self.renderer = renderer
        self.sequencer = sequencer
    }

    deinit {
        appendTask?.cancel()
        bufferingFlushTask?.cancel()
        finishTask?.cancel()
        streamTask?.cancel()
        tailUpdateTask?.cancel()
    }
}

// MARK: - Public Lifecycle

extension QuillStreamCoordinator {
    func append(
        _ chunk: String,
        currentMarkdown: String?,
        configuration: QuillRenderConfiguration,
        needsRestart: Bool
    ) {
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

    func cancelStreaming(configuration: QuillRenderConfiguration) {
        streamTask?.cancel()
        streamTask = nil
        finishTask?.cancel()
        finishTask = nil
        appendTask?.cancel()
        appendTask = nil
        cancelBufferedFlush()
        moduleStreamGate.reset()
        cancelTailUpdate()
        controller = nil
        streamGeneration += 1
        sequencer.reset()
        renderer.clearTail()
        onHeightInvalidated?()
    }

    func finish(configuration: QuillRenderConfiguration) {
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
            self.renderer.clearTail()
            self.onHeightInvalidated?()
        }
    }

    func resetStreamRendering() {
        streamTask?.cancel()
        streamTask = nil
        finishTask?.cancel()
        finishTask = nil
        appendTask?.cancel()
        appendTask = nil
        cancelBufferedFlush()
        moduleStreamGate.reset()
        cancelTailUpdate()
        controller = nil
        streamGeneration += 1
        sequencer.reset()

        renderer.reset()
        renderedFrozenCount = 0
    }

    func applyConfiguration(_ configuration: QuillRenderConfiguration) {
        renderer.tailConfiguration = configuration.tail
        moduleStreamGate.updateConfiguration(
            ModuleStreamGateConfiguration(
                minModuleLength: configuration.bufferedStream.minModuleLength,
                maxBufferingDelay: configuration.bufferedStream.maxBufferingDelay
            )
        )
        sequencer.applyConfiguration(
            typewriter: configuration.typewriter,
            performanceProfile: configuration.performanceProfile
        )
        sequencer.setFixedTiming(
            configuration.streamingMode == .bufferedModules
                ? RevealSequencer.ResolvedTiming(
                    charsPerStep: 4,
                    baseDuration: 0.014,
                    elementGapDuration: 0.04,
                    commaPause: 0.03,
                    sentencePause: 0.08,
                    jitterMax: 0.005
                )
                : nil
        )
        sequencer.setMinimumTextAnimationWindow(
            configuration.streamingMode == .bufferedModules
                ? 0.4
                : 0
        )

        if configuration.streamingMode != .bufferedModules {
            cancelBufferedFlush()
            moduleStreamGate.reset()
        }

        if configuration.streamingMode == .stableBlocks
            || configuration.streamingMode == .bufferedModules {
            cancelTailUpdate()
            renderer.clearTail()
            onHeightInvalidated?()
        }
    }
}

// MARK: - Stream Task

private extension QuillStreamCoordinator {
    func startStream(bootstrap: String? = nil, configuration: QuillRenderConfiguration) {
        cancelStreaming(configuration: configuration)

        let streamController = MarkdownStreamController()
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
                    var newBlocks = Array(state.blocks[self.renderedFrozenCount..<newFrozen])
                    let firstFrozenBlock = newBlocks.first
                    let promotedTail = self.promoteTailIfPossible(
                        firstFrozenBlock: firstFrozenBlock,
                        configuration: configuration
                    )
                    if promotedTail {
                        newBlocks.removeFirst()
                    }

                    self.renderedFrozenCount = newFrozen

                    let views = self.renderer.append(blocks: newBlocks)
                    for view in views {
                        self.sequencer.enqueue(view: view)
                    }

                    if !promotedTail,
                       configuration.streamingMode == .hybridTail,
                       firstFrozenBlock != nil {
                        self.renderer.clearTail()
                    }
                }

                self.updateTailPreview(for: state, configuration: configuration)
            }
        }
    }

    func promoteTailIfPossible(firstFrozenBlock: Block?, configuration: QuillRenderConfiguration) -> Bool {
        guard configuration.streamingMode == .hybridTail,
              let firstFrozenBlock
        else {
            return false
        }

        return renderer.promoteTailIfMatching(firstFrozenBlock) != nil
    }
}

// MARK: - Tail Management

private extension QuillStreamCoordinator {
    func updateTailPreview(for state: BlockReducer.ReducerState, configuration: QuillRenderConfiguration) {
        guard configuration.streamingMode == .hybridTail else {
            cancelTailUpdate()
            renderer.clearTail()
            return
        }

        if state.blocks.count > state.frozenCount,
           let tailBlock = state.blocks.last {
            if shouldApplyTailImmediately(tailBlock, configuration: configuration) {
                cancelTailUpdate()
                renderer.updateTail(block: tailBlock)
                onHeightInvalidated?()
            } else {
                scheduleTailUpdate(block: tailBlock, configuration: configuration)
            }
        } else {
            cancelTailUpdate()
            renderer.clearTail()
            onHeightInvalidated?()
        }
    }

    func scheduleTailUpdate(block: Block, configuration: QuillRenderConfiguration) {
        pendingTailBlock = block
        guard tailUpdateTask == nil else { return }

        let coalescingInterval = max(0, configuration.tail.flowTailUpdateCoalescingInterval)
        tailUpdateTask = Task { [weak self] in
            guard let self else { return }
            defer { self.tailUpdateTask = nil }

            if coalescingInterval > 0 {
                try? await Task.sleep(for: .seconds(coalescingInterval))
            }

            guard !Task.isCancelled else { return }
            let latestTailBlock = self.pendingTailBlock
            self.pendingTailBlock = nil

            guard let latestTailBlock else { return }
            self.renderer.updateTail(block: latestTailBlock)
            self.onHeightInvalidated?()
        }
    }

    func cancelTailUpdate() {
        tailUpdateTask?.cancel()
        tailUpdateTask = nil
        pendingTailBlock = nil
    }

    func shouldApplyTailImmediately(_ block: Block, configuration: QuillRenderConfiguration) -> Bool {
        guard configuration.tail.flowTailUpdateCoalescingInterval > 0 else {
            return true
        }

        switch block {
        case .codeBlock, .table:
            return true
        case .blockquote, .heading, .htmlBlock, .orderedList, .paragraph, .thematicBreak, .unorderedList:
            return false
        }
    }
}

// MARK: - Buffered Append

private extension QuillStreamCoordinator {
    func appendBufferedChunk(_ chunk: String, to streamController: MarkdownStreamController, configuration: QuillRenderConfiguration) {
        let now = Date.timeIntervalSinceReferenceDate
        let result = moduleStreamGate.append(chunk, now: now)
        enqueueCommittedChunks(result.committedChunks, to: streamController)

        if result.hasPendingText {
            scheduleBufferedFlushIfNeeded(streamController: streamController, now: now, configuration: configuration)
        } else {
            cancelBufferedFlush()
        }
    }

    func enqueueAppendChunk(_ chunk: String, to streamController: MarkdownStreamController) {
        guard chunk.isEmpty == false else { return }

        let previousTask = appendTask
        appendTask = Task {
            await previousTask?.value
            guard !Task.isCancelled else { return }
            await streamController.append(chunk)
        }
    }

    func enqueueCommittedChunks(_ chunks: [String], to streamController: MarkdownStreamController) {
        for chunk in chunks where chunk.isEmpty == false {
            enqueueAppendChunk(chunk, to: streamController)
        }
    }

    func scheduleBufferedFlushIfNeeded(streamController: MarkdownStreamController, now: TimeInterval, configuration: QuillRenderConfiguration) {
        cancelBufferedFlush()
        let delay = moduleStreamGate.timeUntilForcedCommit(now: now) ?? 0.12
        let effectiveDelay = max(0.05, delay)

        bufferingFlushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(effectiveDelay))
            guard let self, !Task.isCancelled else { return }
            self.flushBufferedInputIfNeeded(streamController: streamController, configuration: configuration)
        }
    }

    func flushBufferedInputIfNeeded(streamController: MarkdownStreamController, configuration: QuillRenderConfiguration) {
        let now = Date.timeIntervalSinceReferenceDate
        let chunks = moduleStreamGate.commitIfOverdue(now: now)
        enqueueCommittedChunks(chunks, to: streamController)

        if moduleStreamGate.hasPendingText {
            scheduleBufferedFlushIfNeeded(streamController: streamController, now: now, configuration: configuration)
        } else {
            cancelBufferedFlush()
        }
    }

    func cancelBufferedFlush() {
        bufferingFlushTask?.cancel()
        bufferingFlushTask = nil
    }
}
