import QuillCore
import UIKit

/// Public UIKit entry point for static and streaming markdown rendering.
@MainActor
public final class QuillView: UIView {
    public var onHeightChange: ((_ old: CGFloat, _ new: CGFloat) -> Void)?
    public var markdown: String? {
        didSet { renderStatic() }
    }

    private let renderer = StreamingBlockRenderer()
    private let sequencer = RevealSequencer()
    private var controller: MarkdownStreamController?
    private var heightInvalidationScheduled = false
    private var lastNotifiedHeight: CGFloat = 0
    private var previousWidth: CGFloat = 0
    private var renderedFrozenCount = 0
    private var streamGeneration = 0
    private var streamTask: Task<Void, Never>?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        streamTask?.cancel()
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
            self.sequencer.finish()
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

    func measureAndNotifyHeight() {
        heightInvalidationScheduled = false
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
        Task { [weak self] in
            await Task.yield()
            self?.measureAndNotifyHeight()
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

                guard newFrozen > self.renderedFrozenCount else { continue }

                let newBlocks = Array(state.blocks[self.renderedFrozenCount..<newFrozen])
                self.renderedFrozenCount = newFrozen

                let views = self.renderer.append(blocks: newBlocks)
                for view in views {
                    self.sequencer.enqueue(view: view)
                }
            }
        }
    }
}
