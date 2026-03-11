import QuillCore
import UIKit

/// Public UIKit entry point for static and streaming markdown rendering.
@MainActor
public final class QuillView: UIView {
    public var onHeightChange: ((_ old: CGFloat, _ new: CGFloat) -> Void)?
    public var markdown: String? {
        didSet { renderStatic() }
    }

    public var configuration: QuillRenderConfiguration {
        didSet { applyConfiguration() }
    }

    private let renderer = StreamingBlockRenderer()
    private let sequencer = RevealSequencer()
    private var controller: MarkdownStreamController?
    private var heightInvalidationScheduled = false
    private var heightUpdateTask: Task<Void, Never>?
    private var lastNotifiedHeight: CGFloat = 0
    private var previousWidth: CGFloat = 0
    private var renderedFrozenCount = 0
    private var streamGeneration = 0
    private var streamTask: Task<Void, Never>?
    private var bufferingFlushTask: Task<Void, Never>?
    private var moduleStreamGate = ModuleStreamGate()
    private var tailUpdateTask: Task<Void, Never>?
    private var pendingTailBlock: Block?

    public init(frame: CGRect = .zero, configuration: QuillRenderConfiguration = .init()) {
        self.configuration = configuration
        super.init(frame: frame)
        commonInit()
        applyConfiguration()
    }

    public override init(frame: CGRect) {
        configuration = QuillRenderConfiguration()
        super.init(frame: frame)
        commonInit()
        applyConfiguration()
    }

    public required init?(coder: NSCoder) {
        configuration = QuillRenderConfiguration()
        super.init(coder: coder)
        commonInit()
        applyConfiguration()
    }

    deinit {
        streamTask?.cancel()
        bufferingFlushTask?.cancel()
        heightUpdateTask?.cancel()
        tailUpdateTask?.cancel()
    }

    public func updateConfiguration(_ mutate: (inout QuillRenderConfiguration) -> Void) {
        var next = configuration
        mutate(&next)
        configuration = next
    }

    public func append(_ chunk: String) {
        if controller == nil {
            startStream()
        }

        guard let streamController = controller else {
            return
        }

        if configuration.streamingMode == .bufferedModules {
            appendBufferedChunk(chunk, to: streamController)
        } else {
            Task { await streamController.append(chunk) }
        }
    }

    public func cancelActiveStream() {
        streamTask?.cancel()
        streamTask = nil
        cancelBufferedFlush()
        moduleStreamGate.reset()
        cancelTailUpdate()
        controller = nil
        streamGeneration += 1
        sequencer.reset()
        renderer.clearTail()
        scheduleHeightUpdate()
    }

    public func finish() {
        guard let streamController = controller else { return }
        controller = nil
        let task = streamTask
        let generation = streamGeneration

        Task { [weak self] in
            guard let self else { return }

            if self.configuration.streamingMode == .bufferedModules {
                self.cancelBufferedFlush()
                let remaining = self.moduleStreamGate.flushRemaining()
                if !remaining.isEmpty {
                    await streamController.append(remaining)
                }
            }

            await streamController.finish()
            await task?.value
            guard self.streamGeneration == generation else {
                return
            }
            self.renderer.clearTail()
            self.scheduleHeightUpdate()
        }
    }

    public func reset() {
        resetStreamRendering()
        sequencer.reset()
        lastNotifiedHeight = 0
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        guard bounds.width != previousWidth else { return }

        previousWidth = bounds.width
        scheduleHeightUpdate()
    }
}

// MARK: - Layout

private extension QuillView {
    func commonInit() {
        let stack = renderer.stackView
        addSubview(stack)

        let bottom = stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottom.priority = .defaultLow

        NSLayoutConstraint.activate([
            bottom,
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        sequencer.onLayoutChange = { [weak self] in
            self?.scheduleHeightUpdate()
        }
        sequencer.onComplete = { [weak self] in
            self?.scheduleHeightUpdate()
        }
    }

    func applyConfiguration() {
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
                    charsPerStep: 6,
                    baseDuration: 0.012,
                    elementGapDuration: 0.04,
                    commaPause: 0.03,
                    sentencePause: 0.08,
                    jitterMax: 0.005
                )
                : nil
        )
        sequencer.setMinimumTextAnimationWindow(
            configuration.streamingMode == .bufferedModules
                ? 0.24
                : 0
        )

        if configuration.streamingMode != .bufferedModules {
            cancelBufferedFlush()
            moduleStreamGate.reset()
        }

        if configuration.streamingMode == .stableBlocks || configuration.streamingMode == .bufferedModules {
            cancelTailUpdate()
            renderer.clearTail()
            scheduleHeightUpdate()
        }
    }

    func measureAndNotifyHeight() {
        heightInvalidationScheduled = false
        heightUpdateTask = nil
        guard bounds.width > 0 else { return }

        setNeedsLayout()
        layoutIfNeeded()
        renderer.stackView.setNeedsLayout()
        renderer.stackView.layoutIfNeeded()

        let newHeight = ceil(renderer.stackView.bounds.height)
        let oldHeight = lastNotifiedHeight
        let minDelta = max(0.5, configuration.layout.heightNotificationMinimumDelta)
        guard abs(newHeight - oldHeight) > minDelta else { return }

        lastNotifiedHeight = newHeight
        onHeightChange?(oldHeight, newHeight)
    }

    func renderStatic() {
        resetStreamRendering()

        guard let markdown, !markdown.isEmpty else {
            lastNotifiedHeight = 0
            return
        }

        let blocks = MarkdownParser.live.parse(markdown)
        renderer.update(blocks: blocks, frozenCount: blocks.count)
        scheduleHeightUpdate()
    }

    func scheduleHeightUpdate() {
        guard !heightInvalidationScheduled else { return }
        heightInvalidationScheduled = true

        let coalescingInterval = max(0, configuration.layout.heightMeasurementCoalescingInterval)
        heightUpdateTask?.cancel()
        heightUpdateTask = Task { [weak self] in
            guard let self else { return }

            if coalescingInterval > 0 {
                try? await Task.sleep(for: .seconds(coalescingInterval))
            }

            guard !Task.isCancelled else { return }
            self.measureAndNotifyHeight()
        }
    }
}

// MARK: - Streaming

private extension QuillView {
    func resetStreamRendering() {
        streamTask?.cancel()
        streamTask = nil
        cancelBufferedFlush()
        moduleStreamGate.reset()
        cancelTailUpdate()
        controller = nil
        streamGeneration += 1

        renderer.reset()
        renderedFrozenCount = 0
    }

    func startStream() {
        cancelActiveStream()

        let streamController = MarkdownStreamController()
        controller = streamController

        let generation = streamGeneration
        streamTask = Task { [weak self] in
            var state = BlockReducer.ReducerState()
            let events = await streamController.events()

            for await event in events {
                guard !Task.isCancelled, let self, self.streamGeneration == generation else { break }

                BlockReducer.apply(event, to: &state)
                let newFrozen = state.frozenCount

                if newFrozen > self.renderedFrozenCount {
                    var newBlocks = Array(state.blocks[self.renderedFrozenCount..<newFrozen])
                    let firstFrozenBlock = newBlocks.first
                    let promotedTail = self.promoteTailIfPossible(firstFrozenBlock: firstFrozenBlock)
                    if promotedTail {
                        newBlocks.removeFirst()
                    }

                    self.renderedFrozenCount = newFrozen

                    let views = self.renderer.append(blocks: newBlocks)
                    for view in views {
                        self.sequencer.enqueue(view: view)
                    }

                    if !promotedTail,
                       self.configuration.streamingMode == .hybridTail,
                       firstFrozenBlock != nil {
                        self.renderer.clearTail()
                    }
                }

                self.updateTailPreview(for: state)
            }
        }
    }

    func promoteTailIfPossible(firstFrozenBlock: Block?) -> Bool {
        guard configuration.streamingMode == .hybridTail,
              let firstFrozenBlock
        else {
            return false
        }

        return renderer.promoteTailIfMatching(firstFrozenBlock) != nil
    }

    func updateTailPreview(for state: BlockReducer.ReducerState) {
        guard configuration.streamingMode == .hybridTail else {
            cancelTailUpdate()
            renderer.clearTail()
            return
        }

        if state.blocks.count > state.frozenCount,
           let tailBlock = state.blocks.last {
            if shouldApplyTailImmediately(tailBlock) {
                cancelTailUpdate()
                renderer.updateTail(block: tailBlock)
                scheduleHeightUpdate()
            } else {
                scheduleTailUpdate(block: tailBlock)
            }
        } else {
            cancelTailUpdate()
            renderer.clearTail()
            scheduleHeightUpdate()
        }
    }

    func scheduleTailUpdate(block: Block) {
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
            self.scheduleHeightUpdate()
        }
    }

    func cancelTailUpdate() {
        tailUpdateTask?.cancel()
        tailUpdateTask = nil
        pendingTailBlock = nil
    }

    func appendBufferedChunk(_ chunk: String, to streamController: MarkdownStreamController) {
        let now = Date.timeIntervalSinceReferenceDate
        let result = moduleStreamGate.append(chunk, now: now)
        enqueueCommittedChunks(result.committedChunks, to: streamController)

        if result.hasPendingText {
            scheduleBufferedFlushIfNeeded(streamController: streamController, now: now)
        } else {
            cancelBufferedFlush()
        }
    }

    func enqueueCommittedChunks(_ chunks: [String], to streamController: MarkdownStreamController) {
        guard chunks.isEmpty == false else { return }
        Task {
            for chunk in chunks where chunk.isEmpty == false {
                await streamController.append(chunk)
            }
        }
    }

    func scheduleBufferedFlushIfNeeded(streamController: MarkdownStreamController, now: TimeInterval) {
        cancelBufferedFlush()
        let delay = moduleStreamGate.timeUntilForcedCommit(now: now) ?? 0.12
        let effectiveDelay = max(0.05, delay)

        bufferingFlushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(effectiveDelay))
            guard let self, !Task.isCancelled else { return }
            self.flushBufferedInputIfNeeded(streamController: streamController)
        }
    }

    func flushBufferedInputIfNeeded(streamController: MarkdownStreamController) {
        let now = Date.timeIntervalSinceReferenceDate
        let chunks = moduleStreamGate.commitIfOverdue(now: now)
        enqueueCommittedChunks(chunks, to: streamController)

        if moduleStreamGate.hasPendingText {
            scheduleBufferedFlushIfNeeded(streamController: streamController, now: now)
        } else {
            cancelBufferedFlush()
        }
    }

    func cancelBufferedFlush() {
        bufferingFlushTask?.cancel()
        bufferingFlushTask = nil
    }

    func shouldApplyTailImmediately(_ block: Block) -> Bool {
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
