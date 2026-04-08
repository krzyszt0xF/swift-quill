import UIKit

@MainActor
final class TableSurfaceView: UIView {
    private let canvasView: TableSurfaceCanvasView
    private lazy var editMenuInteraction = UIEditMenuInteraction(delegate: self)
    private let scrollView = UIScrollView()
    private let theme: QuillTheme
    var onCopy: OnCopy? = CopyAction.live

    private var contentVersion = 0
    private var currentLayoutCacheKey: LayoutCacheKey?
    private var layoutCache: [LayoutCacheKey: TableSurfaceLayout] = [:]
    private var content = TableSurfaceContent(
        columnAlignments: [],
        header: TableSurfaceRowContent(cells: []),
        rows: []
    )

    init(
        theme: QuillTheme = .default,
        frame: CGRect = .zero
    ) {
        self.theme = theme
        canvasView = TableSurfaceCanvasView(theme: theme)
        super.init(frame: frame)

        addInteraction(editMenuInteraction)
        backgroundColor = .clear
        isOpaque = false
        setupScrollView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    var selection: TableSurfaceSelection? {
        get { canvasView.selection }
        set { canvasView.selection = newValue }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(copy(_:)), #selector(share(_:)):
            return selection != nil
        default:
            return false
        }
    }

    override func copy(_ sender: Any?) {
        guard let selection else { return }
        let tsv = canvasView.layoutModel.makeTSV(selection: selection)
        guard tsv.isEmpty == false else { return }
        onCopy?(tsv)
        self.selection = nil
        editMenuInteraction.dismissMenu()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        rebuildLayoutIfNeeded()

        scrollView.frame = bounds

        let layout = canvasView.layoutModel
        let contentWidth = max(layout.contentSize.width, scrollView.bounds.width)
        let contentSize = CGSize(width: contentWidth, height: layout.contentSize.height)
        canvasView.frame = CGRect(origin: .zero, size: contentSize)
        canvasView.viewportWidth = scrollView.bounds.width
        scrollView.contentSize = contentSize
    }

    func configure(content: TableSurfaceContent) {
        self.content = content
        contentVersion += 1
        currentLayoutCacheKey = nil
        selection = nil
        layoutCache.removeAll(keepingCapacity: true)
        setNeedsLayout()
    }

    @objc
    func share(_ sender: Any?) {
        guard let selection else { return }
        let tsv = canvasView.layoutModel.makeTSV(selection: selection)
        guard tsv.isEmpty == false else { return }

        let activityViewController = UIActivityViewController(
            activityItems: [tsv],
            applicationActivities: nil
        )
        activityViewController.completionWithItemsHandler = { [weak self] _, _, _, _ in
            guard let self else { return }
            self.selection = nil
            self.editMenuInteraction.dismissMenu()
        }

        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = canvasView
            popover.sourceRect = canvasView.menuTargetRect ?? .zero
        }

        nearestViewController()?.present(activityViewController, animated: true)
    }
}

private extension TableSurfaceView {
    struct LayoutCacheKey: Hashable {
        let contentVersion: Int
        let viewportWidth: Int
    }

    func rebuildLayoutIfNeeded() {
        let viewportWidth = max(bounds.width, 320)
        let cacheKey = LayoutCacheKey(
            contentVersion: contentVersion,
            viewportWidth: Int(viewportWidth.rounded())
        )
        guard cacheKey != currentLayoutCacheKey else { return }

        currentLayoutCacheKey = cacheKey
        if let cachedLayout = layoutCache[cacheKey] {
            canvasView.layoutModel = cachedLayout
            return
        }

        let layout = TableSurfaceLayoutBuilder.makeLayout(
            content: content,
            viewportWidth: viewportWidth,
            theme: theme
        )
        layoutCache[cacheKey] = layout
        canvasView.layoutModel = layout
    }

    func setupScrollView() {
        scrollView.alwaysBounceVertical = false
        scrollView.backgroundColor = .clear
        scrollView.delaysContentTouches = false
        scrollView.isOpaque = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = false

        canvasView.onLinkSelection = { [weak self] url in
            self?.makeDocumentTextView()?.onLinkSelection?(url)
        }
        canvasView.onSelectionChanged = { [weak self] in
            guard self?.selection == nil else { return }
            self?.editMenuInteraction.dismissMenu()
        }
        canvasView.onSelectionCommitted = { [weak self] in
            self?.presentSelectionMenuIfNeeded()
        }

        addSubview(scrollView)
        scrollView.addSubview(canvasView)
    }

    func presentSelectionMenuIfNeeded() {
        guard selection != nil else {
            editMenuInteraction.dismissMenu()
            return
        }

        _ = becomeFirstResponder()
        let targetRect = convert(canvasView.menuTargetRect ?? .zero, from: canvasView)
        let sourcePoint = CGPoint(x: targetRect.midX, y: targetRect.midY)
        editMenuInteraction.presentEditMenu(
            with: UIEditMenuConfiguration(
                identifier: nil,
                sourcePoint: sourcePoint
            )
        )
    }

    func nearestViewController() -> UIViewController? {
        sequence(first: next, next: { $0?.next }).first { $0 is UIViewController } as? UIViewController
    }

    func makeDocumentTextView() -> DocumentTextView? {
        sequence(first: superview, next: { $0?.superview })
            .first { $0 is DocumentTextView } as? DocumentTextView
    }
}

extension TableSurfaceView: @MainActor UIEditMenuInteractionDelegate {
    func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        guard selection != nil else { return nil }

        let copyAction = UIAction(title: "Copy") { [weak self] _ in
            self?.copy(nil)
        }
        let shareAction = UIAction(title: "Share") { [weak self] _ in
            self?.share(nil)
        }

        return UIMenu(children: [copyAction, shareAction])
    }

    func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        targetRectFor configuration: UIEditMenuConfiguration
    ) -> CGRect {
        convert(canvasView.menuTargetRect ?? .zero, from: canvasView)
    }
}
