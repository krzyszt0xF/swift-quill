import QuillCore
import UIKit

@MainActor
public final class QuillView: UIView {
    public private(set) var accumulatedMarkdown: String?
    public var configuration = QuillConfiguration.default {
        didSet {
            guard
                streamCoordinator.hasActiveController == false,
                markdown != nil || accumulatedMarkdown != nil
            else { return }

            renderStatic(source: markdown ?? accumulatedMarkdown)
        }
    }

    public var onHeightChange: ((_ old: CGFloat, _ new: CGFloat) -> Void)? {
        didSet { heightCoordinator.onHeightChange = onHeightChange }
    }

    public var onLinkSelection: ((URL) -> Void)? {
        didSet { streamCoordinator.onLinkSelection = onLinkSelection }
    }

    package var onStreamFinished: (() -> Void)? {
        didSet { streamCoordinator.onStreamFinished = onStreamFinished }
    }

    public var syntaxHighlighter: (any SyntaxHighlighting)? {
        didSet { streamCoordinator.syntaxHighlighter = syntaxHighlighter }
    }

    public var imageLoader: (any ImageLoading)? {
        didSet { streamCoordinator.imageLoader = imageLoader }
    }

    public var markdown: String? {
        didSet {
            guard markdown != oldValue else { return }
            renderStatic(source: markdown)
        }
    }

    // Active streams render against a frozen snapshot so later public configuration changes
    // do not alter content mid-stream.
    private var activeConfiguration = QuillConfiguration.default
    private let heightCoordinator: HeightCoordinator
    private let markdownParser: MarkdownParser
    private var staticParseTask: Task<Void, Never>?
    let streamCoordinator: StreamCoordinator

    deinit {
        staticParseTask?.cancel()
    }

    public convenience init(
        frame: CGRect = .zero,
        configuration: QuillConfiguration = .default
    ) {
        self.init(frame: frame)
        self.configuration = configuration
        activeConfiguration = configuration
        streamCoordinator.apply(configuration: configuration)
    }

    override public init(frame: CGRect) {
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
        configuration: QuillConfiguration,
        dependencies: Dependencies
    ) {
        heightCoordinator = dependencies.heightCoordinator
        markdownParser = dependencies.markdownParser
        streamCoordinator = dependencies.streamCoordinator
        super.init(frame: frame)
        self.configuration = configuration
        activeConfiguration = configuration
        setup()
    }

    public func append(_ chunk: String) {
        staticParseTask?.cancel()
        staticParseTask = nil
        let needsRestart = !streamCoordinator.hasActiveController
        let existingContent = accumulatedMarkdown ?? ""
        if needsRestart {
            activeConfiguration = configuration
        }

        let nextContent = existingContent + chunk
        let bootstrapContent: String? = if needsRestart, existingContent.isEmpty == false {
            nextContent
        } else {
            nil
        }
        let streamedChunk = bootstrapContent == nil ? chunk : ""
        accumulatedMarkdown = nextContent

        streamCoordinator.append(
            streamedChunk,
            accumulatedMarkdown: bootstrapContent,
            configuration: activeConfiguration,
            needsRestart: needsRestart
        )
    }

    public func cancelStreaming() {
        streamCoordinator.cancelStreaming()
    }

    public func finish() {
        streamCoordinator.finish(configuration: activeConfiguration)
    }

    public func reset() {
        staticParseTask?.cancel()
        staticParseTask = nil
        accumulatedMarkdown = nil
        streamCoordinator.reset()
        heightCoordinator.resetLastNotifiedHeight()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        guard heightCoordinator.handleWidthChange(newWidth: bounds.width) else { return }
        scheduleHeightUpdate()
    }
}

private extension QuillView {
    /// Inputs at or below this UTF-8 byte size parse synchronously so content is applied before
    /// SwiftUI measures (Issue 01). Internal heuristic, not consumer-configurable.
    static let synchronousInitialParseThreshold = 16_384

    nonisolated static func makeStaticBlocks(
        from source: String,
        parser: MarkdownParser
    ) async -> [BlockNode] {
        parseBlocks(from: source, parser: parser)
    }

    nonisolated static func parseBlocks(
        from source: String,
        parser: MarkdownParser
    ) -> [BlockNode] {
        let signpostID = QuillSignpost.parse.makeSignpostID()
        let signpostState = QuillSignpost.parse.beginInterval("parseStatic", id: signpostID)
        let blocks = parser.parse(source)
        QuillSignpost.parse.endInterval("parseStatic", signpostState)
        return blocks
    }

    func renderStatic(source: String?) {
        staticParseTask?.cancel()
        staticParseTask = nil
        accumulatedMarkdown = source
        activeConfiguration = configuration

        guard let source, !source.isEmpty else {
            streamCoordinator.reset()
            heightCoordinator.resetLastNotifiedHeight()
            return
        }

        let parser = markdownParser
        let config = activeConfiguration

        // Parse small inputs synchronously so content is applied before SwiftUI's `.fixedSize`
        // measure; larger inputs stay on the background task (Issue 01).
        if source.utf8.count <= Self.synchronousInitialParseThreshold {
            let blocks = Self.parseBlocks(from: source, parser: parser)
            streamCoordinator.renderStatic(blocks: blocks, configuration: config)
            return
        }

        staticParseTask = Task {
            let blocks = await Self.makeStaticBlocks(from: source, parser: parser)

            guard !Task.isCancelled else { return }
            streamCoordinator.renderStatic(
                blocks: blocks,
                configuration: config
            )
        }
    }

    func scheduleHeightUpdate() {
        heightCoordinator.scheduleHeightUpdate(
            hostView: self,
            contentRevision: streamCoordinator.hostView.contentRevision,
            documentTextView: streamCoordinator.hostView,
            configuration: activeConfiguration.renderConfiguration.layout
        )
    }

    func setup() {
        let documentView = streamCoordinator.hostView
        documentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(documentView)

        let bottom = documentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottom.priority = .defaultLow

        NSLayoutConstraint.activate([
            bottom,
            documentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            documentView.topAnchor.constraint(equalTo: topAnchor),
            documentView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        streamCoordinator.apply(configuration: activeConfiguration)
        streamCoordinator.onHeightInvalidated = { [weak self] in
            self?.scheduleHeightUpdate()
        }
    }
}
