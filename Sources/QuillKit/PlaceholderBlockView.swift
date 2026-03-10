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
    private var minimumHeightConstraint: NSLayoutConstraint?

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

    static func image(title: String?) -> PlaceholderBlockView {
        let view = PlaceholderBlockView()
        view.iconView.image = UIImage(systemName: "photo")
        view.label.text = title ?? "Image"
        view.setMinimumHeight(Layout.imageMinimumHeight)
        return view
    }

    static func table(header: Block.TableRow, rowCount: Int) -> PlaceholderBlockView {
        let view = PlaceholderBlockView()
        view.iconView.image = UIImage(systemName: "tablecells")

        let columns = header.cells.count
        let totalRows = rowCount + 1
        let dimensions = "Table (\(columns)x\(totalRows))"
        let headerNames = header.cells
            .map { plainText(from: $0.content) }
            .joined(separator: " | ")

        view.label.text = "\(dimensions)\n\(headerNames)"
        view.setMinimumHeight(Layout.tableMinimumHeight)
        return view
    }
}

private extension PlaceholderBlockView {
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
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentHuggingPriority(.required, for: .vertical)
        iconView.setContentCompressionResistancePriority(.required, for: .vertical)

        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.alignment = .center
        stack.axis = .vertical
        stack.spacing = Layout.stackSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setContentHuggingPriority(.defaultHigh, for: .vertical)
        stack.setContentCompressionResistancePriority(.required, for: .vertical)

        addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.heightAnchor.constraint(equalToConstant: Layout.iconSize),
            iconView.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.contentInset),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Layout.contentInset),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Layout.contentInset),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Layout.contentInset),
        ])
    }

    func setMinimumHeight(_ height: CGFloat) {
        minimumHeightConstraint?.isActive = false
        let constraint = heightAnchor.constraint(greaterThanOrEqualToConstant: height)
        constraint.priority = .required
        constraint.isActive = true
        minimumHeightConstraint = constraint
    }
}
