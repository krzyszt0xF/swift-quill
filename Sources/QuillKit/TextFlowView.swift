import UIKit

final class TextFlowView: UIView {
    private let textContentStorage = NSTextContentStorage()
    private let textContainer = NSTextContainer()
    private let textLayoutManager = NSTextLayoutManager()
    private var heightConstraint: NSLayoutConstraint?

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: heightConstraint?.constant ?? 0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTextContainer()

        backgroundColor = .clear
        isOpaque = false
        
        translatesAutoresizingMaskIntoConstraints = false
        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        heightConstraint?.priority = .required
        heightConstraint?.isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        textLayoutManager.enumerateTextLayoutFragments(
            from: textLayoutManager.documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            fragment.draw(at: fragment.layoutFragmentFrame.origin, in: context)
            return true
        }

        drawBlockquoteBars(in: context)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }

    func configure(with attributedString: NSAttributedString) {
        textContentStorage.attributedString = attributedString
        setNeedsDisplay()
    }

    func updateRawText(_ text: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label,
        ]
        textContentStorage.attributedString = NSAttributedString(string: text, attributes: attributes)
        setNeedsDisplay()
    }
}

private extension TextFlowView {
    func drawBlockquoteBars(in context: CGContext) {
        guard let attrString = textContentStorage.attributedString else { 
            return 
        }

        let fullRange = NSRange(location: 0, length: attrString.length)

        attrString.enumerateAttribute(.blockquoteDepth, in: fullRange) { value, range, _ in
            guard let depth = value as? Int, depth > 0 else { 
                return 
            }

            let yExtents = yRange(for: range)
            guard yExtents.max > yExtents.min else { 
                return 
            }

            let x = CGFloat(depth - 1) * 16
            let barRect = CGRect(x: x, y: yExtents.min, width: 3, height: yExtents.max - yExtents.min)
            context.setFillColor(UIColor.systemGray3.cgColor)
            context.fill(barRect)
        }
    }

    func setupTextContainer() {
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.size = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textLayoutManager.textContainer = textContainer
        textContentStorage.addTextLayoutManager(textLayoutManager)
    }

    func updateLayout() {
        textContainer.size = CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
        textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)

        var maxY: CGFloat = 0
        textLayoutManager.enumerateTextLayoutFragments(
            from: textLayoutManager.documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            let fragmentMaxY = fragment.layoutFragmentFrame.maxY
            if fragmentMaxY > maxY { maxY = fragmentMaxY }
            return true
        }

        if maxY == 0, let attrString = textContentStorage.attributedString, attrString.length > 0 {
            let boundingSize = CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
            maxY = attrString.boundingRect(
                with: boundingSize,
                options: [.usesLineFragmentOrigin],
                context: nil
            ).height
        }

        heightConstraint?.constant = ceil(maxY)
        invalidateIntrinsicContentSize()
    }

    func yRange(for characterRange: NSRange) -> (min: CGFloat, max: CGFloat) {
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxY: CGFloat = 0

        guard let start = textLayoutManager.location(
            textLayoutManager.documentRange.location,
            offsetBy: characterRange.location
        ) else { return (0, 0) }

        guard let end = textLayoutManager.location(
            start,
            offsetBy: characterRange.length
        ) else { return (0, 0) }

        let textRange = NSTextRange(location: start, end: end)

        textLayoutManager.enumerateTextLayoutFragments(
            from: textRange?.location,
            options: [.ensuresLayout]
        ) { fragment in
            let loc = fragment.rangeInElement.location
            guard let range = textRange, loc.compare(range.endLocation) != .orderedDescending else { 
                return false 
            }

            let frame = fragment.layoutFragmentFrame
            if frame.minY < minY { minY = frame.minY }
            if frame.maxY > maxY { maxY = frame.maxY }
            
            return true
        }

        return (minY == .greatestFiniteMagnitude ? 0 : minY, maxY)
    }
}