import QuillCore
import UIKit

final class PlaceholderBlockView: UIView {
    private enum Layout {
        static let contentInset: CGFloat = 12
        static let imageMinimumHeight: CGFloat = 96
        static let stackSpacing: CGFloat = 4
        static let tableMinimumHeight: CGFloat = 110
        static let iconSize: CGFloat = 44
    }

    private let iconView = UIImageView()
    private let label = UILabel()
    private var minimumHeight: CGFloat = Layout.imageMinimumHeight
    var revealProgress: CGFloat = 1

    override var intrinsicContentSize: CGSize {
        let measuredWidth = resolvedMeasurementWidth(from: bounds.width)
        guard measuredWidth > 0 else {
            return CGSize(width: UIView.noIntrinsicMetric, height: scaledHeight(for: minimumMeasuredHeight))
        }

        return CGSize(width: UIView.noIntrinsicMetric, height: scaledHeight(for: measuredHeight(for: measuredWidth)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemGray6
        clipsToBounds = true
        layer.cornerRadius = 8
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultHigh, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let measuredWidth = resolvedMeasurementWidth(from: size.width)
        guard measuredWidth > 0 else {
            return CGSize(width: size.width, height: scaledHeight(for: minimumMeasuredHeight))
        }

        return CGSize(width: measuredWidth, height: scaledHeight(for: measuredHeight(for: measuredWidth)))
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let contentWidth = max(bounds.width - (Layout.contentInset * 2), 0)
        label.preferredMaxLayoutWidth = contentWidth

        let labelHeight = labelHeight(for: bounds.width)
        let totalContentHeight = Layout.iconSize + Layout.stackSpacing + labelHeight
        let contentOriginY = max(Layout.contentInset, (bounds.height - totalContentHeight) / 2)

        iconView.frame = CGRect(
            x: (bounds.width - Layout.iconSize) / 2,
            y: contentOriginY,
            width: Layout.iconSize,
            height: Layout.iconSize
        )
        label.frame = CGRect(
            x: Layout.contentInset,
            y: iconView.frame.maxY + Layout.stackSpacing,
            width: contentWidth,
            height: labelHeight
        )
    }

    static func image(title: String?) -> PlaceholderBlockView {
        let view = PlaceholderBlockView()
        view.configureImage(title: title)
        return view
    }

    static func table(header: Block.TableRow, rowCount: Int) -> PlaceholderBlockView {
        let view = PlaceholderBlockView()
        view.configureTable(header: header, rowCount: rowCount)
        return view
    }

    func configureImage(title: String?) {
        iconView.image = UIImage(systemName: "photo")
        label.text = title ?? "Image"
        minimumHeight = Layout.imageMinimumHeight
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func configureTable(header: Block.TableRow, rowCount: Int) {
        iconView.image = UIImage(systemName: "tablecells")

        let columns = header.cells.count
        let totalRows = rowCount + 1
        let dimensions = "Table (\(columns)x\(totalRows))"
        let headerNames = header.cells
            .map { Self.plainText(from: $0.content) }
            .joined(separator: " | ")

        label.text = "\(dimensions)\n\(headerNames)"
        minimumHeight = Layout.tableMinimumHeight
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
}

private extension PlaceholderBlockView {
    func measuredHeight(for width: CGFloat) -> CGFloat {
        max(
            minimumMeasuredHeight,
            (Layout.contentInset * 2) + Layout.iconSize + Layout.stackSpacing + labelHeight(for: width)
        )
    }

    var minimumMeasuredHeight: CGFloat {
        max(minimumHeight, (Layout.contentInset * 2) + Layout.iconSize)
    }

    static func plainText(from inlines: [Inline]) -> String {
        inlines.map { plainText(from: $0) }.joined()
    }

    static func plainText(from inline: Inline) -> String {
        switch inline {
        case let .code(text):
            return text
        case let .emphasis(children):
            return plainText(from: children)
        case let .image(_, _, alt):
            return plainText(from: alt)
        case .inlineHTML:
            return ""
        case .lineBreak:
            return " "
        case let .link(_, children):
            return plainText(from: children)
        case let .strikethrough(children):
            return plainText(from: children)
        case let .strong(children):
            return plainText(from: children)
        case let .text(string):
            return string
        }
    }

    func setupLayout() {
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: Layout.iconSize)
        iconView.tintColor = .secondaryLabel

        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        addSubview(iconView)
        addSubview(label)
    }

    func resolvedMeasurementWidth(from proposedWidth: CGFloat) -> CGFloat {
        if proposedWidth > 0, proposedWidth != UIView.noIntrinsicMetric {
            return proposedWidth
        }
        return bounds.width
    }

    func scaledHeight(for height: CGFloat) -> CGFloat {
        ceil(max(0, height * revealProgress))
    }

    func labelHeight(for width: CGFloat) -> CGFloat {
        let availableWidth = max(width - (Layout.contentInset * 2), 0)
        return label.sizeThatFits(CGSize(width: availableWidth, height: .greatestFiniteMagnitude)).height
    }
}

extension PlaceholderBlockView: BlockRevealAnimating {
    func currentRevealHeight() -> CGFloat {
        let width = resolvedMeasurementWidth(from: bounds.width)
        return scaledHeight(for: width > 0 ? measuredHeight(for: width) : minimumMeasuredHeight)
    }
}
