import QuillCore
import UIKit

@MainActor
public final class QuillView: UIView {
    public var onHeightChange: ((_ old: CGFloat, _ new: CGFloat) -> Void)? {
        didSet { heightCoordinator.onHeightChange = onHeightChange }
    }

    public var onLinkTap: ((URL) -> Void)? {
        didSet {
            renderer.onLinkTap = onLinkTap
            renderer.rebindLinkTapHandlers()
        }
    }

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

    private let heightCoordinator = QuillHeightCoordinator()
    private let renderer: StreamingBlockRenderer
    private let sequencer = RevealSequencer()
    private let streamCoordinator: QuillStreamCoordinator

    public init(frame: CGRect = .zero, streamingPreset: QuillStreamingPreset = .balanced) {
        self.streamingPreset = streamingPreset
        self.internalConfiguration = QuillConfigurationMapper.resolve(streamingPreset)
        self.renderer = StreamingBlockRenderer()
        self.streamCoordinator = QuillStreamCoordinator(renderer: renderer, sequencer: sequencer)
        super.init(frame: frame)
        commonInit()
        applyInternalConfiguration()
    }

    init(frame: CGRect, internalConfiguration: QuillRenderConfiguration) {
        self.streamingMode = internalConfiguration.streamingMode
        self.internalConfiguration = internalConfiguration
        self.renderer = StreamingBlockRenderer()
        self.streamCoordinator = QuillStreamCoordinator(renderer: renderer, sequencer: sequencer)
        super.init(frame: frame)
        commonInit()
        applyInternalConfiguration()
    }

    public override init(frame: CGRect) {
        self.renderer = StreamingBlockRenderer()
        self.streamCoordinator = QuillStreamCoordinator(renderer: renderer, sequencer: sequencer)
        super.init(frame: frame)
        commonInit()
        applyInternalConfiguration()
    }

    public required init?(coder: NSCoder) {
        self.renderer = StreamingBlockRenderer()
        self.streamCoordinator = QuillStreamCoordinator(renderer: renderer, sequencer: sequencer)
        super.init(coder: coder)
        commonInit()
        applyInternalConfiguration()
    }

    public func append(_ chunk: String) {
        let needsRestart = !streamCoordinator.hasActiveController
        let previousContent = needsRestart ? currentMarkdown : nil

        currentMarkdown = (currentMarkdown ?? "") + chunk

        streamCoordinator.append(
            chunk,
            currentMarkdown: previousContent,
            configuration: internalConfiguration,
            needsRestart: needsRestart
        )
    }

    public func cancelStreaming() {
        streamCoordinator.cancelStreaming(configuration: internalConfiguration)
    }

    public func finish() {
        streamCoordinator.finish(configuration: internalConfiguration)
    }

    public func reset() {
        currentMarkdown = nil
        streamCoordinator.resetStreamRendering()
        sequencer.reset()
        heightCoordinator.resetLastNotifiedHeight()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        guard heightCoordinator.handleWidthChange(newWidth: bounds.width) else { return }
        scheduleHeightUpdate()
    }
}

// MARK: - Setup

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

        sequencer.onLayoutChange = { [weak self] view in
            if let self, let view {
                self.renderer.containerView.invalidateBlockLayout(for: view)
            }
            self?.scheduleHeightUpdate()
        }
        sequencer.onComplete = { [weak self] in
            self?.scheduleHeightUpdate()
        }

        streamCoordinator.onHeightInvalidated = { [weak self] in
            self?.scheduleHeightUpdate()
        }
    }

    func applyPreset() {
        internalConfiguration = QuillConfigurationMapper.resolve(streamingPreset)
        internalConfiguration.streamingMode = streamingMode
        applyInternalConfiguration()
    }

    func applyInternalConfiguration() {
        streamCoordinator.applyConfiguration(internalConfiguration)
    }

    func renderStatic() {
        streamCoordinator.resetStreamRendering()
        currentMarkdown = markdown

        guard let markdown, !markdown.isEmpty else {
            heightCoordinator.resetLastNotifiedHeight()
            return
        }

        let blocks = MarkdownParser.live.parse(markdown)
        renderer.update(blocks: blocks, frozenCount: blocks.count)
        scheduleHeightUpdate()
    }

    func scheduleHeightUpdate() {
        heightCoordinator.scheduleHeightUpdate(
            hostView: self,
            containerView: renderer.hostView,
            configuration: internalConfiguration.layout
        )
    }
}
