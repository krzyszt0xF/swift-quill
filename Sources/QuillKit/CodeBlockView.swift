import UIKit

final class CodeBlockView: UIView {
    private let languagePill = PaddedLabel()
    private let scrollView = UIScrollView()
    private let textView = UITextView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemGray6
        clipsToBounds = true
        layer.cornerRadius = 8
        translatesAutoresizingMaskIntoConstraints = false

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

    func configure(language: String?, code: String) {
        let trimmed = code.hasSuffix("\n") ? String(code.dropLast()) : code
        textView.text = trimmed
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .label

        if let language, !language.isEmpty {
            languagePill.text = language
            languagePill.isHidden = false
        } else {
            languagePill.isHidden = true
        }
    }

    func updateCode(_ code: String) {
        let trimmed = code.hasSuffix("\n") ? String(code.dropLast()) : code
        textView.text = trimmed
    }
}

private extension CodeBlockView {
    func setupLanguagePill() {
        languagePill.backgroundColor = .systemGray5
        languagePill.clipsToBounds = true
        languagePill.font = .systemFont(ofSize: 11, weight: .medium)
        languagePill.isUserInteractionEnabled = false
        languagePill.layer.cornerRadius = 4
        languagePill.textColor = .secondaryLabel
        languagePill.translatesAutoresizingMaskIntoConstraints = false

        addSubview(languagePill)
        NSLayoutConstraint.activate([
            languagePill.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            languagePill.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])
    }

    func setupScrollView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
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

        scrollView.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            textView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            textView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            textView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            textView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
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
