import UIKit

@MainActor
final class TableSurfaceCanvasView: UIView {
    var layoutModel = TableSurfaceLayout.empty {
        didSet {
            selection = nil
            setNeedsDisplay()
        }
    }

    var menuTargetRect: CGRect?
    var onLinkSelection: ((URL) -> Void)?
    var onSelectionChanged: (() -> Void)?
    var onSelectionCommitted: (() -> Void)?

    var selection: TableSurfaceSelection? {
        didSet {
            updateHandles()
            setNeedsDisplay()
            onSelectionChanged?()
        }
    }

    var viewportWidth: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }

    private let leadingHandle = TableSurfaceSelectionHandleView(isLeading: true)
    private let theme: QuillTheme
    private let trailingHandle = TableSurfaceSelectionHandleView(isLeading: false)

    init(
        theme: QuillTheme,
        frame: CGRect = .zero
    ) {
        self.theme = theme
        super.init(frame: frame)

        backgroundColor = .clear
        isOpaque = false

        addSubview(leadingHandle)
        addSubview(trailingHandle)
        installGestures()
        updateHandles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        drawSelection(in: context)
        drawCellText()
        drawSeparators(in: context)
    }
}

private extension TableSurfaceCanvasView {
    enum Layout {
        static let separatorWidth: CGFloat = 1
    }

    func drawCellText() {
        for cell in layoutModel.cells {
            cell.textLayout.draw(at: cell.textFrame.origin)
        }
    }

    func drawSelection(in context: CGContext) {
        guard let selection else { return }

        context.saveGState()
        defer { context.restoreGState() }

        context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.24).cgColor)
        for rect in layoutModel.selectionRects(for: selection) {
            context.fill(rect.integral.insetBy(dx: -0.5, dy: -0.5))
        }
    }

    func drawSeparators(in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        context.setFillColor(theme.table.separatorColor.cgColor)

        for xPosition in layoutModel.verticalSeparatorXPositions {
            context.fill(CGRect(
                x: xPosition,
                y: 0,
                width: theme.table.separatorWidth,
                height: layoutModel.contentSize.height
            ))
        }

        for yPosition in layoutModel.horizontalSeparatorYPositions {
            context.fill(CGRect(
                x: 0,
                y: yPosition,
                width: max(layoutModel.contentSize.width, viewportWidth),
                height: theme.table.separatorWidth
            ))
        }
    }

    func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        let point = recognizer.location(in: self)

        switch recognizer.state {
        case .began:
            guard let position = layoutModel.selectionPosition(at: point) else { return }
            selection = TableSurfaceSelection(anchor: position, focus: position)
        case .changed:
            guard let currentSelection = selection,
                  let position = layoutModel.selectionPosition(at: point) else {
                return
            }
            selection = TableSurfaceSelection(anchor: currentSelection.anchor, focus: position)
        case .ended:
            updateMenuTargetRect()
            onSelectionCommitted?()
        default:
            break
        }
    }

    func handleTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        if let url = layoutModel.link(at: point) {
            onLinkSelection?(url)
            return
        }

        selection = nil
        menuTargetRect = nil
    }

    func installGestures() {
        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPressGesture(_:))
        )
        longPress.allowableMovement = .greatestFiniteMagnitude
        longPress.minimumPressDuration = 0.14

        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTapGesture(_:))
        )

        addGestureRecognizer(longPress)
        addGestureRecognizer(tap)
    }

    @objc
    func handleLongPressGesture(_ recognizer: UILongPressGestureRecognizer) {
        handleLongPress(recognizer)
    }

    @objc
    func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        handleTap(recognizer)
    }

    func updateHandles() {
        guard let selection else {
            leadingHandle.isHidden = true
            trailingHandle.isHidden = true
            menuTargetRect = nil
            return
        }

        guard let handleFrames = layoutModel.handleFrames(for: selection) else {
            leadingHandle.isHidden = true
            trailingHandle.isHidden = true
            menuTargetRect = nil
            return
        }

        leadingHandle.isHidden = false
        trailingHandle.isHidden = false
        leadingHandle.frame = handleFrames.leading
        trailingHandle.frame = handleFrames.trailing
        updateMenuTargetRect()
    }

    func updateMenuTargetRect() {
        guard let selection else {
            menuTargetRect = nil
            return
        }

        let rects = layoutModel.selectionRects(for: selection)
        guard let first = rects.first else {
            menuTargetRect = nil
            return
        }

        menuTargetRect = rects.dropFirst().reduce(first) { partialResult, rect in
            partialResult.union(rect)
        }
    }
}
