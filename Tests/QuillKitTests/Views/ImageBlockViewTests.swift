@testable import QuillKit
import QuillCore
import Testing
import UIKit

@MainActor
@Suite("ImageBlockView", .tags(.rendering))
struct ImageBlockViewTests {
    @Test("Configure shows loading state")
    func configureShowsLoadingState() {
        let view = ImageBlockView()
        view.configure(content: makeContent(), appearance: .default, retryEnabled: true)

        #expect(contentImageView(in: view)?.isHidden == true)
        #expect(errorControl(in: view)?.isHidden == true)
        #expect(retryLabel(in: view)?.text == "Tap to retry")
    }

    @Test("Loaded image shows image view and hides error")
    func loadedImageShowsImageView() {
        let view = ImageBlockView()
        let image = makeImage(width: 120, height: 60)
        view.configure(content: makeContent(), appearance: .default, retryEnabled: true)

        view.apply(imageLoadResult: .loaded(image))

        #expect(contentImageView(in: view)?.isHidden == false)
        #expect(contentImageView(in: view)?.image?.size == image.size)
        #expect(errorControl(in: view)?.isHidden == true)
    }

    @Test("Failed load shows error state")
    func failedLoadShowsErrorState() {
        let view = ImageBlockView()
        view.configure(content: makeContent(), appearance: .default, retryEnabled: true)

        view.apply(imageLoadResult: .failed)

        #expect(errorControl(in: view)?.isHidden == false)
        #expect(contentImageView(in: view)?.isHidden == true)
        #expect(retryLabel(in: view)?.text == "Tap to retry")
    }

    @Test("Retry enabled keeps interactive retry affordance")
    func retryEnabledKeepsInteractiveAffordance() {
        let view = ImageBlockView()
        view.configure(content: makeContent(), appearance: .default, retryEnabled: true)
        view.apply(imageLoadResult: .failed)

        #expect(errorControl(in: view)?.isUserInteractionEnabled == true)
        #expect(retryLabel(in: view)?.text == "Tap to retry")
    }

    @Test("Retry disabled removes retry affordance")
    func retryDisabledRemovesRetryAffordance() {
        let view = ImageBlockView()
        view.configure(content: makeContent(), appearance: .default, retryEnabled: false)
        view.apply(imageLoadResult: .failed)

        #expect(errorControl(in: view)?.isUserInteractionEnabled == false)
        #expect(retryLabel(in: view)?.text == "Unable to load")
    }
}

private extension ImageBlockViewTests {
    func makeContent() -> ImageBlockContent {
        ImageBlockContent(
            alt: "cover",
            blockID: BlockIdentity(rawValue: 1),
            source: "https://example.com/image.png"
        )
    }

    func makeImage(
        width: CGFloat,
        height: CGFloat,
        color: UIColor = .systemGreen
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func contentImageView(in view: UIView) -> UIImageView? {
        view.firstSubview {
            $0.contentMode == .scaleAspectFill
        }
    }

    func errorControl(in view: UIView) -> UIControl? {
        view.firstSubview()
    }

    func retryLabel(in view: UIView) -> UILabel? {
        view.firstSubview()
    }
}
