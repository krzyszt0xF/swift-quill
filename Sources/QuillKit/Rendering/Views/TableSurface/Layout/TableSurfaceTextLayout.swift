import UIKit

final class TableSurfaceTextLayout {
    let attributedText: NSAttributedString
    let textContainer: NSTextContainer

    private let layoutManager: NSLayoutManager
    private let textStorage: NSTextStorage

    var usedHeight: CGFloat {
        ceil(layoutManager.usedRect(for: textContainer).height)
    }

    init(
        attributedText: NSAttributedString,
        width: CGFloat
    ) {
        self.attributedText = attributedText
        textStorage = NSTextStorage(attributedString: attributedText)
        layoutManager = NSLayoutManager()
        textContainer = NSTextContainer(size: CGSize(width: max(width, 1), height: .greatestFiniteMagnitude))

        textContainer.lineBreakMode = .byCharWrapping
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureLayout(for: textContainer)
    }

    static func measureSingleLineWidth(attributedText: NSAttributedString) -> CGFloat {
        ceil(attributedText.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 30),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).width)
    }
}

extension TableSurfaceTextLayout {
    func characterIndex(at point: CGPoint) -> Int {
        guard attributedText.length > 0 else { return 0 }

        let clampedPoint = CGPoint(
            x: max(0, min(point.x, textContainer.size.width)),
            y: max(0, point.y)
        )
        var fraction: CGFloat = 0
        let index = layoutManager.characterIndex(
            for: clampedPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: &fraction
        )
        let candidate = fraction > 0.5 ? index + 1 : index
        return min(max(candidate, 0), attributedText.length)
    }

    func draw(at point: CGPoint) {
        let glyphRange = NSRange(location: 0, length: layoutManager.numberOfGlyphs)
        guard glyphRange.length > 0 else { return }

        layoutManager.drawBackground(forGlyphRange: glyphRange, at: point)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: point)
    }

    func link(at point: CGPoint) -> URL? {
        guard attributedText.length > 0 else { return nil }
        let index = min(max(characterIndex(at: point), 0), max(attributedText.length - 1, 0))
        return attributedText.attribute(.link, at: index, effectiveRange: nil) as? URL
    }

    func selectionRects(for range: NSRange) -> [CGRect] {
        guard attributedText.length > 0, range.length > 0 else { return [] }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rects: [CGRect] = []
        layoutManager.enumerateEnclosingRects(
            forGlyphRange: glyphRange,
            withinSelectedGlyphRange: glyphRange,
            in: textContainer
        ) { rect, _ in
            rects.append(rect.integral)
        }

        return rects
    }
}
