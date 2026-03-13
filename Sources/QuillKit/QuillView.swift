import QuillCore
import UIKit

@MainActor
public final class QuillView: UIView {
    public var onHeightChange: ((_ old: CGFloat, _ new: CGFloat) -> Void)?

    public var markdown: String? {
        didSet { renderStatic() }
    }

    public private(set) var currentMarkdown: String?

    public var streamingMode: StreamingMode = .bufferedModules {
        didSet {
            internalConfiguration.streamingMode = streamingMode
            applyInternalConfiguration()
        }
    }

    public var streamingPreset: QuillStreamingPreset = .balanced {
        didSet { applyPreset() }
    }

    private var internalConfiguration = QuillConfigurationMapper.resolve(.balanced)

    private let renderer: StreamingBlockRenderer
    private let sequencer = RevealSequencer()
    private var controller: MarkdownStreamController?
    private var heightInvalidationScheduled = false
    private var heightUpdateTask: Task<Void, Never>?
    private var lastNotifiedHeight: CGFloat = 0
    private var previousWidth: CGFloat = 0
    private var renderedFrozenCount = 0
    private var streamGeneration = 0
    private var streamTask: Task<Void, Never>?
    private var finishTask: Task<Void, Never>?
    private var appendTask: Task<Void, Never>?
    private var bufferingFlushTask: Task<Void, Never>?
    private var moduleStreamGate = ModuleStreamGate()
    private var tailUpdateTask: Task<Void, Never>?
    private var pendingTailBlock: Block?
    public init(frame: CGRect = .zero, streamingPreset: QuillStreamingPreset = .balanced) {
        self.streamingPreset = streamingPreset
        self.internalConfiguration = QuillConfigurationMapper.resolve(streamingPreset)
        self.renderer = StreamingBlockRenderer()
        super.init(frame: frame)
        commonInit()
        applyInternalConfiguration()
    }

    init(frame: CGRect, internalConfiguration: QuillRenderConfiguration) {
        self.streamingMode = internalConfiguration.streamingMode
        self.internalConfiguration = internalConfiguration
        self.renderer = StreamingBlockRenderer()
        super.init(frame: frame)
        commonInit()
        applyInternalConfiguration()
    }

    public override init(frame: CGRect) {
        self.renderer = StreamingBlockRenderer()
        super.init(frame: frame)
        commonInit()
        applyInternalConfiguration()
    }

    public required init?(coder: NSCoder) {
        self.renderer = StreamingBlockRenderer()
        super.init(coder: coder)
        commonInit()
        applyInternalConfiguration()
    }

    deinit {
        streamTask?.cancel()
        finishTask?.cancel()
        appendTask?.cancel()
        bufferingFlushTask?.cancel()
        heightUpdateTask?.cancel()
        tailUpdateTask?.cancel()
    }

    public func append(_ chunk: String) {
        let needsRestart = controller == nil
        let previousContent = needsRestart ? currentMarkdown : nil

        currentMarkdown = (currentMarkdown ?? "") + chunk

        if needsRestart {
            startStream(bootstrap: previousContent)
        }

        guard let streamController = controller else { return }

        if internalConfiguration.streamingMode == .bufferedModules {
            appendBufferedChunk(chunk, to: streamController)
        } else {
            enqueueAppendChunk(chunk, to: streamController)
        }
    }

    public func cancelStreaming() {
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
        scheduleHeightUpdate()
    }

    public func finish() {
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

            if self.internalConfiguration.streamingMode == .bufferedModules {
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
            self.scheduleHeightUpdate()
        }
    }

    public func reset() {
        currentMarkdown = nil
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
        let host = renderer.hostView
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)

        let bottom = host.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottom.priority = .defaultLow

        NSLayoutConstraint.activate([
            bottom,
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        sequencer.onLayoutChange = { [weak self] in
            self?.scheduleHeightUpdate()
        }
        sequencer.onComplete = { [weak self] in
            self?.scheduleHeightUpdate()
        }
    }

    func applyPreset() {
        internalConfiguration = QuillConfigurationMapper.resolve(streamingPreset)
        internalConfiguration.streamingMode = streamingMode
        applyInternalConfiguration()
    }

    func applyInternalConfiguration() {
        renderer.tailConfiguration = internalConfiguration.tail
        moduleStreamGate.updateConfiguration(
            ModuleStreamGateConfiguration(
                minModuleLength: internalConfiguration.bufferedStream.minModuleLength,
                maxBufferingDelay: internalConfiguration.bufferedStream.maxBufferingDelay
            )
        )
        sequencer.applyConfiguration(
            typewriter: internalConfiguration.typewriter,
            performanceProfile: internalConfiguration.performanceProfile
        )
        sequencer.setFixedTiming(
            internalConfiguration.streamingMode == .bufferedModules
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
            internalConfiguration.streamingMode == .bufferedModules
                ? 0.24
                : 0
        )

        if internalConfiguration.streamingMode != .bufferedModules {
            cancelBufferedFlush()
            moduleStreamGate.reset()
        }

        if internalConfiguration.streamingMode == .stableBlocks
            || internalConfiguration.streamingMode == .bufferedModules {
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
        renderer.hostView.setNeedsLayout()
        renderer.hostView.layoutIfNeeded()

        let newHeight = ceil(renderer.hostView.bounds.height)
        let oldHeight = lastNotifiedHeight
        let minDelta = max(0.5, internalConfiguration.layout.heightNotificationMinimumDelta)
        guard abs(newHeight - oldHeight) > minDelta else { return }

        lastNotifiedHeight = newHeight
        onHeightChange?(oldHeight, newHeight)
    }

    func renderStatic() {
        resetStreamRendering()
        currentMarkdown = markdown

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

        let coalescingInterval = max(0, internalConfiguration.layout.heightMeasurementCoalescingInterval)
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
        finishTask?.cancel()
        finishTask = nil
        appendTask?.cancel()
        appendTask = nil
        cancelBufferedFlush()
        moduleStreamGate.reset()
        cancelTailUpdate()
        controller = nil
        streamGeneration += 1

        renderer.reset()
        renderedFrozenCount = 0
    }

    func startStream(bootstrap: String? = nil) {
        cancelStreaming()

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
                       self.internalConfiguration.streamingMode == .hybridTail,
                       firstFrozenBlock != nil {
                        self.renderer.clearTail()
                    }
                }

                self.updateTailPreview(for: state)
            }
        }
    }

    func promoteTailIfPossible(firstFrozenBlock: Block?) -> Bool {
        guard internalConfiguration.streamingMode == .hybridTail,
              let firstFrozenBlock
        else {
            return false
        }

        return renderer.promoteTailIfMatching(firstFrozenBlock) != nil
    }

    func updateTailPreview(for state: BlockReducer.ReducerState) {
        guard internalConfiguration.streamingMode == .hybridTail else {
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

        let coalescingInterval = max(0, internalConfiguration.tail.flowTailUpdateCoalescingInterval)
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
        for chunk in chunks where chunk.isEmpty == false {
            enqueueAppendChunk(chunk, to: streamController)
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
        guard internalConfiguration.tail.flowTailUpdateCoalescingInterval > 0 else {
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
