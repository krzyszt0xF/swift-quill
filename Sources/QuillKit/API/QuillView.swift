import QuillCore
import UIKit

@MainActor
public final class QuillView: UIView {
    public private(set) var currentMarkdown: String?
    
    public var onHeightChange: ((_ old: CGFloat, _ new: CGFloat) -> Void)? {
        didSet { heightCoordinator.onHeightChange = onHeightChange }
    }

    public var onLinkTap: ((URL) -> Void)? {
        didSet { streamCoordinator.onLinkTap = onLinkTap }
    }

    public var markdown: String? {
        didSet { renderStatic() }
    }

    public var streamingMode: StreamingMode = .bufferedModules {
        didSet {
            configuration.streamingMode = streamingMode
            streamCoordinator.applyConfiguration(configuration)
        }
    }

    public var streamingPreset: QuillStreamingPreset = .balanced {
        didSet { applyPreset() }
    }

    private var configuration = RenderConfiguration(preset: .balanced)
    private let heightCoordinator: HeightCoordinator
    private let markdownParser: MarkdownParser
    private let streamCoordinator: StreamCoordinator
    
    public convenience init(frame: CGRect = .zero, preset: QuillStreamingPreset) {
        self.init(frame: frame)
        self.streamingPreset = preset
        applyPreset()
    }

    public override init(frame: CGRect) {
        let dependencies = Dependencies.live
        heightCoordinator = dependencies.heightCoordinator
        markdownParser = dependencies.markdownParser
        streamCoordinator = dependencies.streamCoordinator
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        let dependencies = Dependencies.live
        heightCoordinator = dependencies.heightCoordinator
        markdownParser = dependencies.markdownParser
        streamCoordinator = dependencies.streamCoordinator
        super.init(coder: coder)
        setup()
    }
    
    package init(
        frame: CGRect = .zero,
        configuration: RenderConfiguration,
        dependencies: Dependencies) {
            heightCoordinator = dependencies.heightCoordinator
            markdownParser = dependencies.markdownParser
            streamCoordinator = dependencies.streamCoordinator
            super.init(frame: frame)
            setup()
            self.configuration = configuration
            streamCoordinator.applyConfiguration(configuration)
        }

    public func append(_ chunk: String) {
        let needsRestart = !streamCoordinator.hasActiveController
        let previousContent = needsRestart ? currentMarkdown : nil

        currentMarkdown = (currentMarkdown ?? "") + chunk

        streamCoordinator.append(
            chunk,
            currentMarkdown: previousContent,
            configuration: configuration,
            needsRestart: needsRestart
        )
    }

    public func cancelStreaming() {
        streamCoordinator.cancelStreaming()
    }

    public func finish() {
        streamCoordinator.finish(configuration: configuration)
    }

    public func reset() {
        currentMarkdown = nil
        streamCoordinator.reset()
        heightCoordinator.resetLastNotifiedHeight()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        guard heightCoordinator.handleWidthChange(newWidth: bounds.width) else { return }
        scheduleHeightUpdate()
    }
}

private extension QuillView {
    func applyPreset() {
        configuration = RenderConfiguration(preset: streamingPreset)
        configuration.streamingMode = streamingMode
        streamCoordinator.applyConfiguration(configuration)
    }

    func renderStatic() {
        currentMarkdown = markdown

        guard let markdown, !markdown.isEmpty else {
            streamCoordinator.reset()
            heightCoordinator.resetLastNotifiedHeight()
            return
        }

        let blocks = markdownParser.parse(markdown)
        streamCoordinator.renderStatic(blocks: blocks)
        scheduleHeightUpdate()
    }

    func scheduleHeightUpdate() {
        heightCoordinator.scheduleHeightUpdate(
            hostView: self,
            containerView: streamCoordinator.hostView,
            configuration: configuration.layout
        )
    }
    
    func setup() {
        let host = streamCoordinator.hostView
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

        streamCoordinator.applyConfiguration(configuration)
        streamCoordinator.onHeightInvalidated = { [weak self] in
            self?.scheduleHeightUpdate()
        }
    }
}
