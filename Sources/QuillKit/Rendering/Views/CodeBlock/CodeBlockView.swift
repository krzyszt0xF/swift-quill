import UIKit

@MainActor
final class CodeBlockView: UIView {
    private let copyButton = UIButton(type: .system)
    private let codeTextView = CodeTextView()
    private let headerView = UIView()
    private let languageLabel = UILabel()
    private let scrollView = UIScrollView()
    private lazy var codeWidthConstraint = codeTextView.widthAnchor.constraint(equalToConstant: 0)
    private var copyRevertTask: Task<Void, Never>?
    private var currentLanguage: String?
    private var metricsCache: Metrics?
    private let theme: QuillTheme

    private(set) var currentCode: String = ""

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: currentMetrics.height
        )
    }

    init(
        theme: QuillTheme = .default,
        frame: CGRect = .zero
    ) {
        self.theme = theme
        super.init(frame: frame)

        backgroundColor = theme.codeBlock.backgroundColor
        clipsToBounds = true
        layer.borderColor = theme.codeBlock.borderColor.cgColor
        layer.borderWidth = theme.codeBlock.borderWidth
        layer.cornerRadius = theme.codeBlock.cornerRadius

        setupHeaderView()
        setupCopyButton()
        setupLanguageLabel()
        setupScrollView()
        setupCodeLabel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width > 0 ? size.width : bounds.width
        return CGSize(
            width: width,
            height: currentMetrics.height
        )
    }

    static func measureHeight(
        of code: String,
        in language: String?,
        theme: QuillTheme
    ) -> CGFloat {
        makeMetrics(
            code: code,
            language: language,
            theme: theme
        ).height
    }

    func apply(highlightedCode: HighlightedCodeSnapshot) {
        let selectedRange = codeTextView.selectedRange
        let contentOffset = scrollView.contentOffset
        let displayCode = CodeBlockDisplayRenderer.makeAttributedString(
            from: highlightedCode,
            code: currentCode,
            theme: theme
        )

        codeTextView.attributedText = displayCode
        updateCodeWidth()
        restoreSelection(selectedRange, textLength: displayCode.length)
        scrollView.setContentOffset(contentOffset, animated: false)
        setStreamingState(false)
    }

    func configure(language: String?, code: String) {
        currentLanguage = normalizedLanguage(language)
        currentCode = code
        metricsCache = nil
        codeTextView.attributedText = CodeBlockDisplayRenderer.makeAttributedString(
            from: currentCode,
            theme: theme
        )
        updateCodeWidth()

        if let currentLanguage {
            languageLabel.text = currentLanguage
            languageLabel.isHidden = false
        } else {
            languageLabel.text = nil
            languageLabel.isHidden = true
        }

        invalidateIntrinsicContentSize()
        setStreamingState(false)
    }

    func setStreamingState(_ streaming: Bool) {
        copyButton.isEnabled = !streaming
        copyButton.alpha = streaming ? 0.4 : 1.0
    }
}

private extension CodeBlockView {
    struct Metrics {
        let code: String
        let height: CGFloat
        let language: String?
        let width: CGFloat
    }

    var currentMetrics: Metrics {
        if let metricsCache,
           metricsCache.code == currentCode,
           metricsCache.language == currentLanguage {
            return metricsCache
        }

        let metrics = Self.makeMetrics(
            code: currentCode,
            language: currentLanguage,
            theme: theme
        )
        metricsCache = metrics
        return metrics
    }

    @objc func copyTapped() {
        UIPasteboard.general.string = currentCode

        copyButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        copyButton.tintColor = theme.codeBlock.copyButtonTint

        copyRevertTask?.cancel()
        copyRevertTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))

            guard !Task.isCancelled, let self else { return }

            self.copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
            self.copyButton.tintColor = self.theme.codeBlock.copyButtonTint
        }
    }

    func restoreSelection(_ selectedRange: NSRange, textLength: Int) {
        guard selectedRange.location != NSNotFound else { return }

        let clampedLocation = min(selectedRange.location, textLength)
        let clampedLength = min(selectedRange.length, textLength - clampedLocation)
        codeTextView.selectedRange = NSRange(location: clampedLocation, length: clampedLength)
    }
}

private extension CodeBlockView {
    func updateCodeWidth() {
        codeWidthConstraint.constant = currentMetrics.width
    }

    func setupCodeLabel() {
        scrollView.addSubview(codeTextView)
        codeTextView.translatesAutoresizingMaskIntoConstraints = false
        codeWidthConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scrollView.contentLayoutGuide.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            codeTextView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            codeTextView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            codeTextView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            codeTextView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            codeTextView.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.widthAnchor),
            codeWidthConstraint,
        ])
    }

    func setupCopyButton() {
        copyButton.tintColor = theme.codeBlock.copyButtonTint
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(
                pointSize: theme.codeBlock.headerFont.pointSize,
                weight: .regular
            ),
            forImageIn: .normal
        )
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)

        headerView.addSubview(copyButton)

        copyButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            copyButton.topAnchor.constraint(equalTo: headerView.topAnchor),
            copyButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            copyButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: Layout.copyButtonSize(theme: theme)),
            copyButton.heightAnchor.constraint(equalToConstant: Layout.copyButtonSize(theme: theme)),
        ])
    }

    func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Layout.insetVertical(theme: theme)),
            headerView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Layout.insetHorizontal(theme: theme)),
            headerView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Layout.insetHorizontal(theme: theme)),
        ])
    }

    func setupLanguageLabel() {
        languageLabel.font = theme.codeBlock.headerFont
        languageLabel.textColor = theme.codeBlock.languageLabelColor
        languageLabel.isHidden = true

        headerView.addSubview(languageLabel)
        languageLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            languageLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            languageLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            languageLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: copyButton.leadingAnchor,
                constant: -theme.codeBlock.padding
            ),
            languageLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
        ])
    }

    func setupScrollView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(
                equalTo: headerView.bottomAnchor,
                constant: Layout.headerToCodeSpacing),
            scrollView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Layout.insetHorizontal(theme: theme)),
            scrollView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Layout.insetHorizontal(theme: theme)),
            scrollView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Layout.insetVertical(theme: theme)),
            scrollView.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Layout.minimumVisibleCodeHeight),
        ])
    }
}

private extension CodeBlockView {
    static func makeMetrics(
        code: String,
        language: String?,
        theme: QuillTheme
    ) -> Metrics {
        let lineCount = max(1, code.components(separatedBy: "\n").count)
        let codeLineHeight = theme.codeBlock.font.lineHeight
        let codeHeight = CGFloat(lineCount) * codeLineHeight
            + CGFloat(max(0, lineCount - 1)) * theme.codeBlock.lineSpacing
        let lines = code.isEmpty ? [""] : code.components(separatedBy: "\n")
        let widestLine = lines.map { line in
            ceil((line as NSString).size(withAttributes: [.font: theme.codeBlock.font]).width)
        }.max() ?? 0
        let height = Layout.insetVertical(theme: theme)
            + Layout.headerHeight(language: language, theme: theme)
            + Layout.headerToCodeSpacing
            + max(Layout.minimumVisibleCodeHeight, ceil(codeHeight))
            + Layout.insetVertical(theme: theme)

        return Metrics(
            code: code,
            height: height,
            language: language,
            width: widestLine
        )
    }

    func normalizedLanguage(_ language: String?) -> String? {
        guard let language, language.isEmpty == false else { return nil }
        return language
    }

    enum Layout {
        static let headerToCodeSpacing: CGFloat = 12
        static let minimumVisibleCodeHeight: CGFloat = 18

        static func copyButtonSize(theme: QuillTheme) -> CGFloat {
            theme.codeBlock.headerFont.pointSize + 8
        }

        static func headerHeight(language: String?, theme: QuillTheme) -> CGFloat {
            let labelHeight = language == nil ? 0 : theme.codeBlock.headerFont.lineHeight
            return max(copyButtonSize(theme: theme), ceil(labelHeight))
        }

        static func insetHorizontal(theme: QuillTheme) -> CGFloat {
            theme.codeBlock.padding
        }

        static func insetVertical(theme: QuillTheme) -> CGFloat {
            theme.codeBlock.padding
        }
    }
}

@MainActor
private final class CodeTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : max(contentSize.width, 1)
        let fittingSize = sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: fittingSize.height)
    }

    override var contentSize: CGSize {
        didSet {
            if oldValue != contentSize {
                invalidateIntrinsicContentSize()
            }
        }
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)

        backgroundColor = .clear
        dataDetectorTypes = []
        isEditable = false
        isScrollEnabled = false
        isSelectable = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        textContainerInset = .zero
        textContainer?.lineBreakMode = .byClipping
        textContainer?.lineFragmentPadding = 0
        textContainer?.widthTracksTextView = false
        textDragInteraction?.isEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension CodeBlockView: CodeBlockHighlightSink {}
