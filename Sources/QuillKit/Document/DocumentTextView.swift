import QuillCore
import UIKit

@MainActor
final class DocumentTextView: UITextView {
    var onLinkSelection: ((URL) -> Void)?
    private(set) var contentRevision = 0
    private let blockquoteBackgroundView = BlockquoteBackgroundView()

    var contentStorage: NSTextContentStorage? {
        textLayoutManager?.textContentManager as? NSTextContentStorage
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard blockquoteBackgroundView.frame != bounds else { return }

        blockquoteBackgroundView.frame = bounds
        blockquoteBackgroundView.invalidateBarRuns()
    }

    init() {
        super.init(frame: .zero, textContainer: nil)

        isEditable = false
        isScrollEnabled = false
        isSelectable = true

        backgroundColor = .clear
        textContainerInset = .zero

        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        delegate = self
        textLayoutManager?.textContainer?.lineFragmentPadding = 0
        dataDetectorTypes = []
        linkTextAttributes = [:]
        textDragInteraction?.isEnabled = false
        blockquoteBackgroundView.backgroundColor = .clear
        blockquoteBackgroundView.isOpaque = false
        blockquoteBackgroundView.isUserInteractionEnabled = false
        blockquoteBackgroundView.textView = self
        insertSubview(blockquoteBackgroundView, at: 0)
    }
}

extension DocumentTextView: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        primaryActionFor textItem: UITextItem,
        defaultAction: UIAction
    ) -> UIAction? {
        guard case let .link(url) = textItem.content else {
            return defaultAction
        }

        let handler = makeLinkSelectionActionHandler(for: url)
        return UIAction { action in
            handler(action)
        }
    }
}

extension DocumentTextView {
    var blockquoteBarRunComputationCount: Int {
        blockquoteBackgroundView.barRunComputationCount
    }

    func handleDocumentContentChange() {
        contentRevision += 1
        blockquoteBackgroundView.invalidateBarRuns()
    }

    func makeLinkSelectionActionHandler(for url: URL) -> UIActionHandler {
        { [weak self] _ in
            _ = self?.handleLinkSelection(url)
        }
    }

    func updateBlockquoteBarRunsIfNeeded() {
        blockquoteBackgroundView.updateBarRunsIfNeeded()
    }

    @discardableResult
    func handleLinkSelection(_ url: URL) -> Bool {
        onLinkSelection?(url)
        return false
    }
}

private final class BlockquoteBackgroundView: UIView {
    weak var textView: DocumentTextView?
    private(set) var barRunComputationCount = 0
    private var cachedBarRuns: [BlockquoteBarLayout.BarRun] = []
    private var needsBarRunUpdate = true

    override func draw(_ rect: CGRect) {
        updateBarRunsIfNeeded()
        guard !cachedBarRuns.isEmpty,
              let context = UIGraphicsGetCurrentContext()
        else { return }

        context.saveGState()
        defer { context.restoreGState() }

        context.clip(to: rect)
        context.setFillColor(BlockquoteStyle.barColor.cgColor)

        for barRun in cachedBarRuns {
            let xOrigin = BlockquoteStyle.barLeadingInset + CGFloat(barRun.level - 1) * BlockquoteStyle.levelSpacing
            let barRect = CGRect(
                x: xOrigin,
                y: barRun.minY,
                width: BlockquoteStyle.barWidth,
                height: barRun.maxY - barRun.minY
            )
            let path = UIBezierPath(
                roundedRect: barRect,
                cornerRadius: BlockquoteStyle.barCornerRadius
            )
            context.addPath(path.cgPath)
            context.fillPath()
        }
    }
}

private extension BlockquoteBackgroundView {
    func invalidateBarRuns() {
        needsBarRunUpdate = true
        setNeedsDisplay()
    }

    func makeBarRuns(for textView: DocumentTextView) -> [BlockquoteBarLayout.BarRun] {
        guard let textLayoutManager = textView.textLayoutManager,
              let contentStorage = textView.contentStorage,
              let attributedString = contentStorage.attributedString
        else { return [] }

        textLayoutManager.ensureLayout(for: bounds)

        var fragments: [BlockquoteBarLayout.FragmentContext] = []
        textLayoutManager.enumerateTextLayoutFragments(from: nil, options: []) { layoutFragment in
            guard let textElement = layoutFragment.textElement,
                  let offset = makeOffset(
                    for: textElement,
                    in: contentStorage
                  ),
                  offset >= 0,
                  offset < attributedString.length,
                  let ownerBlockID = attributedString.attribute(
                      .ownerBlockID, at: offset, effectiveRange: nil
                  ) as? BlockIdentity,
                  let blockquoteDepth = attributedString.attribute(
                      .blockquoteDepth, at: offset, effectiveRange: nil
                  ) as? Int,
                  blockquoteDepth > 0
            else { return true }

            let frame = layoutFragment.layoutFragmentFrame
            fragments.append(
                BlockquoteBarLayout.FragmentContext(
                    ownerBlockID: ownerBlockID,
                    depth: blockquoteDepth,
                    maxY: frame.maxY,
                    minY: frame.minY
                )
            )
            return true
        }

        return BlockquoteBarLayout.makeRuns(from: fragments)
    }

    func updateBarRunsIfNeeded() {
        guard needsBarRunUpdate else { return }

        guard let textView else {
            cachedBarRuns = []
            needsBarRunUpdate = false
            return
        }

        cachedBarRuns = makeBarRuns(for: textView)
        barRunComputationCount += 1
        needsBarRunUpdate = false
    }

    func makeOffset(
        for textElement: NSTextElement,
        in contentStorage: NSTextContentStorage
    ) -> Int? {
        guard let elementRange = textElement.elementRange else { return nil }

        return contentStorage.offset(
            from: contentStorage.documentRange.location,
            to: elementRange.location
        )
    }
}
