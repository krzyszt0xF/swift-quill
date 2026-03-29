import UIKit

@MainActor
final class TableSurfaceSelectionHandleView: UIView {
    private let isLeading: Bool

    init(isLeading: Bool) {
        self.isLeading = isLeading
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: 22, height: 28)))
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.saveGState()
        defer { context.restoreGState() }

        let color = UIColor.systemBlue
        context.setFillColor(color.cgColor)

        let circleDiameter: CGFloat = 14
        let lineWidth: CGFloat = 3
        let circleY = isLeading ? 0 : bounds.height - circleDiameter
        let lineRect = CGRect(
            x: (bounds.width - lineWidth) / 2,
            y: isLeading ? circleDiameter - 1 : 0,
            width: lineWidth,
            height: bounds.height - circleDiameter + 1
        )
        let circleRect = CGRect(
            x: (bounds.width - circleDiameter) / 2,
            y: circleY,
            width: circleDiameter,
            height: circleDiameter
        )

        context.fillEllipse(in: circleRect)
        context.fill(lineRect)
    }
}
