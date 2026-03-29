import UIKit

@MainActor
final class TableSurfaceView: UIView {
    private let canvasView = TableSurfaceCanvasView()
    private let scrollView = UIScrollView()

    private var currentViewportWidth: CGFloat = 0
    private var content = TableSurfaceContent(
        columnAlignments: [],
        header: TableSurfaceRowContent(cells: []),
        rows: []
    )

    override init(frame: CGRect) {
        super.init(frame: frame)

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
        UIPasteboard.general.string = tsv
        self.selection = nil
        UIMenuController.shared.hideMenu()
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
        selection = nil
        currentViewportWidth = 0
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
            UIMenuController.shared.hideMenu()
        }

        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = canvasView
            popover.sourceRect = canvasView.menuTargetRect ?? .zero
        }

        nearestViewController()?.present(activityViewController, animated: true)
    }
}

private extension TableSurfaceView {
    func rebuildLayoutIfNeeded() {
        let viewportWidth = max(bounds.width, 320)
        guard abs(viewportWidth - currentViewportWidth) > 0.5 else { return }

        currentViewportWidth = viewportWidth
        canvasView.layoutModel = TableSurfaceLayoutBuilder.makeLayout(
            content: content,
            viewportWidth: viewportWidth
        )
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
            UIMenuController.shared.hideMenu()
        }
        canvasView.onSelectionCommitted = { [weak self] in
            self?.presentSelectionMenuIfNeeded()
        }

        addSubview(scrollView)
        scrollView.addSubview(canvasView)
    }

    func presentSelectionMenuIfNeeded() {
        guard selection != nil else {
            UIMenuController.shared.hideMenu()
            return
        }

        _ = becomeFirstResponder()
        UIMenuController.shared.showMenu(
            from: canvasView,
            rect: canvasView.menuTargetRect ?? .zero
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
