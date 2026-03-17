import UIKit

final class CodeBlockView: UIView {
    private enum Layout {
        static let codeHorizontalInset: CGFloat = 12
        static let codeVerticalInset: CGFloat = 12
        static let headerToCodeSpacing: CGFloat = 8
        static let minimumVisibleCodeHeight: CGFloat = 18
        static let pillHeight: CGFloat = 20
        static let pillTrailingInset: CGFloat = 8
    }

    private let headerView = UIView()
    private let languagePill = PaddedLabel()
    private let scrollView = UIScrollView()
    private let textView = UITextView()
    private var headerHeightConstraint: NSLayoutConstraint?
    private var contentTopConstraint: NSLayoutConstraint?
    var revealProgress: CGFloat = 1

    private(set) var currentLanguage: String?

    override var intrinsicContentSize: CGSize {
        revealIntrinsicContentSize
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemGray6
        clipsToBounds = true
        layer.cornerRadius = 8
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        setupHeaderView()
        setupScrollView()
        setupTextView()
        setupLanguagePill()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }

        scrollView.showsHorizontalScrollIndicator = true
        scrollView.flashScrollIndicators()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.scrollView.showsHorizontalScrollIndicator = false
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        revealSizeThatFits(size)
    }

    func configure(language: String?, code: String) {
        currentLanguage = language
        textView.text = trimmedCode(code)
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .label

        if let language, !language.isEmpty {
            languagePill.text = language
            languagePill.isHidden = false
            headerHeightConstraint?.constant = Layout.pillHeight
            contentTopConstraint?.constant = Layout.headerToCodeSpacing
        } else {
            languagePill.text = nil
            languagePill.isHidden = true
            headerHeightConstraint?.constant = 0
            contentTopConstraint?.constant = 0
        }

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func updateCode(_ code: String) {
        textView.text = trimmedCode(code)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
}

private extension CodeBlockView {
    func trimmedCode(_ code: String) -> String {
        code.hasSuffix("\n") ? String(code.dropLast()) : code
    }

    func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerView)

        let height = headerView.heightAnchor.constraint(equalToConstant: 0)
        headerHeightConstraint = height

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor, constant: Layout.codeVerticalInset),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.codeHorizontalInset),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.codeHorizontalInset),
            height,
        ])
    }

    func setupLanguagePill() {
        languagePill.backgroundColor = .systemGray5
        languagePill.clipsToBounds = true
        languagePill.font = .systemFont(ofSize: 11, weight: .medium)
        languagePill.isUserInteractionEnabled = false
        languagePill.layer.cornerRadius = 4
        languagePill.textColor = .secondaryLabel
        languagePill.translatesAutoresizingMaskIntoConstraints = false
        languagePill.isHidden = true

        headerView.addSubview(languagePill)
        NSLayoutConstraint.activate([
            languagePill.topAnchor.constraint(equalTo: headerView.topAnchor),
            languagePill.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            languagePill.leadingAnchor.constraint(greaterThanOrEqualTo: headerView.leadingAnchor),
            languagePill.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -Layout.pillTrailingInset),
        ])
    }

    func setupScrollView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        addSubview(scrollView)
        let top = scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor)
        contentTopConstraint = top

        NSLayoutConstraint.activate([
            top,
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.codeVerticalInset),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minimumVisibleCodeHeight),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.codeHorizontalInset),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.codeHorizontalInset),
        ])
    }

    func setupTextView() {
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.size.width = CGFloat.greatestFiniteMagnitude
        textView.textContainer.widthTracksTextView = false
        textView.textContainerInset = .zero
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)

        scrollView.addSubview(textView)
        let matchingHeight = textView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        matchingHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            textView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            matchingHeight,
            textView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            textView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            textView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            textView.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }
}

private extension CodeBlockView {
    final class PaddedLabel: UILabel {
        override var intrinsicContentSize: CGSize {
            let size = super.intrinsicContentSize
            return CGSize(width: size.width + 8, height: size.height + 4)
        }

        override func drawText(in rect: CGRect) {
            super.drawText(in: rect.insetBy(dx: 4, dy: 2))
        }
    }
}

extension CodeBlockView: BlockRevealAnimating {
    var minimumMeasuredHeight: CGFloat {
        let headerHeight = (currentLanguage?.isEmpty == false) ? Layout.pillHeight + Layout.headerToCodeSpacing : 0
        return (Layout.codeVerticalInset * 2) + headerHeight + Layout.minimumVisibleCodeHeight
    }

    func measuredHeight(for width: CGFloat) -> CGFloat {
        let availableWidth = max(width - (Layout.codeHorizontalInset * 2), 0)
        let codeHeight = max(
            Layout.minimumVisibleCodeHeight,
            textView.sizeThatFits(CGSize(width: availableWidth, height: .greatestFiniteMagnitude)).height
        )
        let headerHeight = headerHeightConstraint?.constant ?? 0
        let contentTopSpacing = contentTopConstraint?.constant ?? 0

        return max(
            minimumMeasuredHeight,
            Layout.codeVerticalInset + headerHeight + contentTopSpacing + codeHeight + Layout.codeVerticalInset
        )
    }
}
