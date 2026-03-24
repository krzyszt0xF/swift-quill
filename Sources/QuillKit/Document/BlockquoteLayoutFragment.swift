import UIKit

final class BlockquoteLayoutFragment: NSTextLayoutFragment {
    private let barDepth: Int

    init(textElement: NSTextElement, range: NSTextRange?, barDepth: Int) {
        self.barDepth = barDepth
        super.init(textElement: textElement, range: range)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var leadingPadding: CGFloat {
        CGFloat(barDepth) * Layout.gutterWidth
    }

    override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)
        drawBlockquoteBars(at: point, in: context)
    }
}

private extension BlockquoteLayoutFragment {
    func drawBlockquoteBars(at point: CGPoint, in context: CGContext) {
        guard barDepth > 0 else { return }

        context.saveGState()
        defer { context.restoreGState() }

        context.setFillColor(UIColor.systemGray2.cgColor)

        let fragmentHeight = max(layoutFragmentFrame.height, renderingSurfaceBounds.height)
        for level in 1...barDepth {
            let xOrigin = point.x + Layout.leadingInset + CGFloat(level - 1) * Layout.gutterWidth
            let barRect = CGRect(x: xOrigin, y: point.y, width: Layout.barWidth, height: fragmentHeight)
            context.fill(barRect)
        }
    }

    enum Layout {
        static let barWidth: CGFloat = 4
        static let gutterWidth: CGFloat = 28
        static let leadingInset: CGFloat = 8
    }
}

@MainActor
final class BlockquoteLayoutFragmentDelegate: NSObject, NSTextLayoutManagerDelegate {
    func install(on layoutManager: NSTextLayoutManager?) {
        layoutManager?.delegate = self
    }

    nonisolated func textLayoutManager(
        _ textLayoutManager: NSTextLayoutManager,
        textLayoutFragmentFor location: NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        let depth = blockquoteDepth(for: textElement, in: textLayoutManager)

        guard depth > 0 else {
            return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange)
        }

        return BlockquoteLayoutFragment(
            textElement: textElement,
            range: textElement.elementRange,
            barDepth: depth
        )
    }
}

private extension BlockquoteLayoutFragmentDelegate {
    nonisolated func blockquoteDepth(for textElement: NSTextElement, in layoutManager: NSTextLayoutManager) -> Int {
        guard let contentStorage = layoutManager.textContentManager as? NSTextContentStorage,
              let elementRange = textElement.elementRange,
              let attributedString = contentStorage.attributedString
        else { return 0 }

        let offset = contentStorage.offset(from: contentStorage.documentRange.location, to: elementRange.location)
        guard offset >= 0, offset < attributedString.length else { return 0 }

        return attributedString.attribute(.blockquoteDepth, at: offset, effectiveRange: nil) as? Int ?? 0
    }
}
