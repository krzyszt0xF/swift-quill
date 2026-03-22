import UIKit

@MainActor
final class CodeBlockView: UIView {
    private let copyButton = UIButton(type: .system)
    private let headerView = UIView()
    private let languageLabel = UILabel()
    private let scrollView = UIScrollView()
    private let codeLabel = UILabel()
    private var copyRevertTask: Task<Void, Never>?
    private lazy var selectionBlockerGesture = makeSelectionBlockerGesture()

    private(set) var currentCode: String = ""

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: Self.measuredHeight(language: languageLabel.text, code: currentCode)
        )
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground
        clipsToBounds = true
        layer.borderColor = UIColor.separator.withAlphaComponent(0.14).cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 20
        
        setupHeaderView()
        setupCopyButton()
        setupLanguageLabel()
        setupScrollView()
        setupCodeLabel()
        addGestureRecognizer(selectionBlockerGesture)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width > 0 ? size.width : bounds.width
        return CGSize(
            width: width,
            height: Self.measuredHeight(language: languageLabel.text, code: currentCode)
        )
    }

    static func measuredHeight(language: String?, code: String) -> CGFloat {
        let displayCode = code.withoutTrailingNewline
        let lineCount = max(1, displayCode.components(separatedBy: "\n").count)
        let lineHeight = UIFont.code.lineHeight
        let codeHeight = CGFloat(lineCount) * lineHeight + CGFloat(max(0, lineCount - 1)) * NSParagraphStyle.code.lineSpacing

        return Layout.Inset.vertical
            + Layout.headerHeight(language: language)
            + Layout.headerToCodeSpacing
            + max(Layout.minimumVisibleCodeHeight, ceil(codeHeight))
            + Layout.Inset.vertical
    }

    func applyHighlightedCode(_ attributedString: NSAttributedString) {
        let highlightedCode = NSMutableAttributedString(attributedString: attributedString)
        highlightedCode.addAttribute(
            .font,
            value: UIFont.code,
            range: NSRange(location: 0, length: highlightedCode.length)
        )
        highlightedCode.addAttribute(
            .paragraphStyle,
            value: NSParagraphStyle.code,
            range: NSRange(location: 0, length: highlightedCode.length)
        )

        codeLabel.attributedText = highlightedCode
        setStreamingState(false)
    }

    func configure(language: String?, code: String) {
        currentCode = code.withoutTrailingNewline
        codeLabel.attributedText = NSAttributedString(
            string: currentCode,
            attributes: [
                .font: UIFont.code,
                .foregroundColor: UIColor.label,
                .paragraphStyle: NSParagraphStyle.code,
            ]
        )

        if let language, !language.isEmpty {
            languageLabel.text = language
            languageLabel.isHidden = false
        } else {
            languageLabel.text = nil
            languageLabel.isHidden = true
        }

        setStreamingState(false)
    }

    func setStreamingState(_ streaming: Bool) {
        copyButton.isEnabled = !streaming
        copyButton.alpha = streaming ? 0.4 : 1.0
    }
}

private extension CodeBlockView {
    @objc func handleSelectionBlockerLongPress() {}

    @objc func copyTapped() {
        UIPasteboard.general.string = currentCode

        copyButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        copyButton.tintColor = .label

        copyRevertTask?.cancel()
        copyRevertTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            
            guard !Task.isCancelled, let self else { return }
            
            self.copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
            self.copyButton.tintColor = .label
        }
    }
}

private extension CodeBlockView {
    func makeSelectionBlockerGesture() -> UILongPressGestureRecognizer {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleSelectionBlockerLongPress))
        gesture.cancelsTouchesInView = true
        gesture.delegate = self
        return gesture
    }

    func setupCodeLabel() {
        codeLabel.numberOfLines = 0
        scrollView.addSubview(codeLabel)
        codeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            codeLabel.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            codeLabel.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            codeLabel.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            codeLabel.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            codeLabel.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }
    
    func setupCopyButton() {
        copyButton.tintColor = .label
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 12, weight: .regular),
            forImageIn: .normal)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)

        headerView.addSubview(copyButton)
        
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            copyButton.topAnchor.constraint(equalTo: headerView.topAnchor),
            copyButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            copyButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: Layout.copyButtonSize),
            copyButton.heightAnchor.constraint(equalToConstant: Layout.copyButtonSize),
        ])
    }

    func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor, constant: Layout.Inset.vertical),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.Inset.horizontal),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.Inset.horizontal)
        ])
    }

    func setupLanguageLabel() {
        languageLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        languageLabel.textColor = .label
        languageLabel.isHidden = true

        headerView.addSubview(languageLabel)
        languageLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            languageLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            languageLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            languageLabel.trailingAnchor.constraint(lessThanOrEqualTo: copyButton.leadingAnchor,constant: -12),
            languageLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])
    }

    func setupScrollView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: Layout.headerToCodeSpacing),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.Inset.horizontal),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.Inset.horizontal),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.Inset.vertical),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minimumVisibleCodeHeight),
        ])
    }
}

private extension CodeBlockView {
    enum Layout {
        enum Inset {
            static let vertical: CGFloat = 12
            static let horizontal: CGFloat = 12
        }
        
        static let copyButtonSize: CGFloat = 20
        static let headerToCodeSpacing: CGFloat = 12
        static let minimumVisibleCodeHeight: CGFloat = 18

        static func headerHeight(language: String?) -> CGFloat {
            let labelHeight = language == nil ? 0 : UIFont.systemFont(ofSize: 12, weight: .semibold).lineHeight
            return max(copyButtonSize, ceil(labelHeight))
        }
    }
}

private extension NSParagraphStyle {
    @MainActor
    static let code: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2
        return style
    }()
}

private extension String {
    var withoutTrailingNewline: String {
        hasSuffix("\n") ? String(self.dropLast()) : self
    }
}

private extension UIFont {
    static let code = UIFont(name: "Menlo-Regular", size: 14) ?? .monospacedSystemFont(ofSize: 14, weight: .regular)
}

extension CodeBlockView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: headerView)
        return copyButton.frame.contains(location) == false
    }
}
