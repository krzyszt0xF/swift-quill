import UIKit

@MainActor
final class ImageBlockView: UIView {
    var onRetry: (() -> Void)? {
        didSet { errorView.onTap = onRetry }
    }

    private let errorView = ErrorView()
    private let imageView = UIImageView()
    private let loadingView = LoadingView()
    private let theme: QuillTheme

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: UIView.noIntrinsicMetric
        )
    }

    init(
        theme: QuillTheme = .default,
        frame: CGRect = .zero
    ) {
        self.theme = theme
        super.init(frame: frame)

        clipsToBounds = true
        layer.cornerRadius = theme.image.cornerRadius

        setupErrorView()
        setupImageView()
        setupLoadingView()
        transition(to: .loading)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        content: ImageBlockContent,
        retryEnabled: Bool = true
    ) {
        accessibilityLabel = content.alt.isEmpty ? "Image" : content.alt
        errorView.update(theme: theme, retryEnabled: retryEnabled)
        loadingView.update(theme: theme)
        transition(to: .loading)
    }
}

extension ImageBlockView: ImageLoadSink {
    func apply(imageLoadResult: ImageLoadResult) {
        switch imageLoadResult {
        case .failed:
            transition(to: .error)
        case let .loaded(image):
            transition(to: .loaded(image))
        }
    }
}

private extension ImageBlockView {
    enum State {
        case error
        case loaded(UIImage)
        case loading
    }

    func transition(to state: State) {
        switch state {
        case .error:
            errorView.isHidden = false
            imageView.isHidden = true
            loadingView.isHidden = true
            loadingView.stopAnimating()
        case let .loaded(image):
            errorView.isHidden = true
            imageView.image = image
            imageView.isHidden = false
            loadingView.isHidden = true
            loadingView.stopAnimating()
            invalidateIntrinsicContentSize()
        case .loading:
            errorView.isHidden = true
            imageView.image = nil
            imageView.isHidden = true
            loadingView.isHidden = false
            loadingView.startAnimating()
        }
    }
}

private extension ImageBlockView {
    func setupErrorView() {
        errorView.isHidden = true

        addSubview(errorView)
        errorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: topAnchor),
            errorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            errorView.bottomAnchor.constraint(equalTo: bottomAnchor),
            errorView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    func setupImageView() {
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.isHidden = true

        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    func setupLoadingView() {
        addSubview(loadingView)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            loadingView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
}

private extension ImageBlockView {
    final class ErrorView: UIControl {
        var onTap: (() -> Void)?

        private let iconView = UIImageView()
        private let label = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)

            addTarget(self, action: #selector(handleTap), for: .touchUpInside)
            setupIconView()
            setupLabel()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(theme: QuillTheme, retryEnabled: Bool) {
            backgroundColor = theme.image.placeholderColor
            iconView.tintColor = theme.image.errorIconColor
            label.textColor = theme.image.errorIconColor
            isUserInteractionEnabled = retryEnabled
            label.text = retryEnabled ? "Tap to retry" : "Unable to load"
        }

        @objc
        func handleTap() {
            onTap?()
        }
    }

    final class LoadingView: UIView {
        private let placeholderView = PlaceholderView()

        override init(frame: CGRect) {
            super.init(frame: frame)
            setupPlaceholderView()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func startAnimating() {
            guard UIAccessibility.isReduceMotionEnabled == false else {
                placeholderView.layer.removeAnimation(forKey: Animation.loadingPulse)
                placeholderView.alpha = 1
                return
            }

            let animation = CABasicAnimation(keyPath: "opacity")
            animation.autoreverses = true
            animation.duration = 1.2
            animation.fromValue = 0.4
            animation.repeatCount = .greatestFiniteMagnitude
            animation.toValue = 1.0
            placeholderView.layer.add(animation, forKey: Animation.loadingPulse)
        }

        func stopAnimating() {
            placeholderView.layer.removeAnimation(forKey: Animation.loadingPulse)
            placeholderView.alpha = 1
        }

        func update(theme: QuillTheme) {
            placeholderView.update(theme: theme)
        }
    }

    final class PlaceholderView: UIView {
        func update(theme: QuillTheme) {
            backgroundColor = theme.image.placeholderColor
        }
    }
}

private extension ImageBlockView.ErrorView {
    func setupIconView() {
        iconView.image = UIImage(systemName: "exclamationmark.triangle")
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 22,
            weight: .semibold
        )

        addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -12),
        ])
    }

    func setupLabel() {
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.text = "Tap to retry"

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
}

private extension ImageBlockView.LoadingView {
    enum Animation {
        static let loadingPulse = "loadingPulse"
    }

    func setupPlaceholderView() {
        addSubview(placeholderView)
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholderView.topAnchor.constraint(equalTo: topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: bottomAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
}
