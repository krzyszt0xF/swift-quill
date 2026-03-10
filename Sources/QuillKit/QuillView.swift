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
        heightUpdateTask?.cancel()
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

        Task { await streamController.append(chunk) }
    }

    public func cancelActiveStream() {
        streamTask?.cancel()
        streamTask = nil
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
            await streamController.finish()
            await task?.value
            guard let self else { return }
            guard self.streamGeneration == generation else {
                return
            }
            self.renderer.clearTail()
            self.sequencer.finish()
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
    }

    func applyConfiguration() {
        renderer.tailConfiguration = configuration.tail
        sequencer.applyConfiguration(
            typewriter: configuration.typewriter,
            performanceProfile: configuration.performanceProfile
        )

        if configuration.streamingMode == .stableBlocks {
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
        guard abs(newHeight - oldHeight) > 0.5 else { return }

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
                    let promotedTail = self.promoteTailIfPossible(firstFrozenBlock: newBlocks.first)
                    if promotedTail {
                        newBlocks.removeFirst()
                    } else {
                        self.renderer.clearTail()
                    }

                    self.renderedFrozenCount = newFrozen

                    let views = self.renderer.append(blocks: newBlocks)
                    for view in views {
                        self.sequencer.enqueue(view: view)
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
            renderer.clearTail()
            scheduleHeightUpdate()
            return
        }

        if state.blocks.count > state.frozenCount,
           let tailBlock = state.blocks.last {
            renderer.updateTail(block: tailBlock)
        } else {
            renderer.clearTail()
        }

        scheduleHeightUpdate()
    }
}
