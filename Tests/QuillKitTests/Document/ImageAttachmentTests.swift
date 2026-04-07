@testable import QuillKit
import QuillCore
import Testing
import UIKit

@MainActor
@Suite("ImageAttachment", .tags(.rendering))
struct ImageAttachmentTests {
    @Test("Attachment stores block ID source and alt text")
    func identityAndPayload() {
        let blockID = BlockIdentity(rawValue: 1)
        let attachment = ImageAttachment(
            blockID: blockID,
            source: "https://example.com/image.png",
            alt: "hero",
            theme: .default
        )

        #expect(attachment.blockID == blockID)
        #expect(attachment.source == "https://example.com/image.png")
        #expect(attachment.alt == "hero")
    }

    @Test("Attachment allows text attachment view")
    func allowsViewProvider() {
        let attachment = ImageAttachment(
            blockID: BlockIdentity(rawValue: 2),
            source: nil,
            alt: "",
            theme: .default
        )

        #expect(attachment.allowsTextAttachmentView == true)
    }

    @Test("Attachment creates image attachment provider")
    func createsImageAttachmentProvider() {
        let attachment = ImageAttachment(
            blockID: BlockIdentity(rawValue: 3),
            source: "https://example.com/image.png",
            alt: "cover",
            theme: .default
        )
        let layoutManager = NSTextLayoutManager()
        let location = layoutManager.documentRange.location

        let provider = attachment.viewProvider(
            for: nil,
            location: location,
            textContainer: nil
        )

        #expect(provider is ImageAttachmentProvider)
    }

    @Test("Provider sets tracksTextAttachmentViewBounds")
    func providerConfiguration() {
        let attachment = ImageAttachment(
            blockID: BlockIdentity(rawValue: 30),
            source: "https://example.com/image.png",
            alt: "cover",
            theme: .default
        )
        let (provider, _) = makeProvider(for: attachment, store: nil)

        #expect(provider.tracksTextAttachmentViewBounds == true)
    }

    @Test("Provider returns width-driven bounds using resolved aspect ratio")
    func widthDrivenBounds() {
        let blockID = BlockIdentity(rawValue: 4)
        let attachment = ImageAttachment(
            blockID: blockID,
            source: "https://example.com/image.png",
            alt: "cover",
            theme: .default
        )
        let store = MockImageLoadStore(aspectRatios: [blockID: 2.0])
        let (provider, location) = makeProvider(for: attachment, store: store)

        let bounds = provider.attachmentBounds(
            for: [:],
            location: location,
            textContainer: nil,
            proposedLineFragment: CGRect(x: 0, y: 0, width: 300, height: 1000),
            position: .zero
        )

        #expect(bounds.width == 300)
        #expect(bounds.height == 150)
    }

    @Test("Provider returns fallback bounds for zero-width proposed fragment")
    func fallbackBoundsForZeroWidth() {
        let attachment = ImageAttachment(
            blockID: BlockIdentity(rawValue: 5),
            source: nil,
            alt: "",
            theme: .default
        )
        let (provider, location) = makeProvider(for: attachment, store: nil)

        let bounds = provider.attachmentBounds(
            for: [:],
            location: location,
            textContainer: nil,
            proposedLineFragment: .zero,
            position: .zero
        )

        #expect(bounds.width > 0)
        #expect(bounds.height > 0)
    }

    @Test("Provider uses fallback aspect ratio when store is nil")
    func fallbackAspectRatioWithoutStore() {
        var theme = QuillTheme.default
        theme.image.fallbackAspectRatio = 4.0 / 3.0
        let attachment = ImageAttachment(
            blockID: BlockIdentity(rawValue: 6),
            source: nil,
            alt: "",
            theme: theme
        )
        let (provider, location) = makeProvider(for: attachment, store: nil)

        let bounds = provider.attachmentBounds(
            for: [:],
            location: location,
            textContainer: nil,
            proposedLineFragment: CGRect(x: 0, y: 0, width: 320, height: 1000),
            position: .zero
        )

        #expect(bounds.height == 240)
    }

    @Test("Provider respects max height guardrail")
    func respectsMaxHeightGuardrail() {
        let blockID = BlockIdentity(rawValue: 7)
        var theme = QuillTheme.default
        theme.image.fallbackAspectRatio = 1
        theme.image.maxHeight = 100
        let attachment = ImageAttachment(
            blockID: blockID,
            source: nil,
            alt: "",
            theme: theme
        )
        let store = MockImageLoadStore(aspectRatios: [blockID: 0.5])
        let (provider, location) = makeProvider(for: attachment, store: store)

        let bounds = provider.attachmentBounds(
            for: [:],
            location: location,
            textContainer: nil,
            proposedLineFragment: CGRect(x: 0, y: 0, width: 300, height: 1000),
            position: .zero
        )

        #expect(bounds.height == 100)
    }

    @Test("Provider loadView creates ImageBlockView")
    func loadViewCreatesImageBlockView() {
        let attachment = ImageAttachment(
            blockID: BlockIdentity(rawValue: 8),
            source: "https://example.com/image.png",
            alt: "cover",
            theme: .default
        )
        let (provider, _) = makeProvider(for: attachment, store: nil)

        provider.loadView()

        #expect(provider.view is ImageBlockView)
    }

    @Test("Provider retry uses ImageLoadStore protocol")
    func providerRetryUsesStoreProtocol() {
        let attachment = ImageAttachment(
            blockID: BlockIdentity(rawValue: 9),
            source: "https://example.com/image.png",
            alt: "cover",
            theme: .default
        )
        let store = MockImageLoadStore(
            loadResults: [BlockIdentity(rawValue: 9): .failed],
            retryEnabled: true
        )
        let (provider, _) = makeProvider(for: attachment, store: store)

        provider.loadView()
        let view = provider.view as? ImageBlockView
        let errorControl: UIControl? = view?.firstSubview()
        errorControl?.sendActions(for: .touchUpInside)

        #expect(store.retryCalls.count == 1)
        #expect(store.retryCalls.first?.blockID == BlockIdentity(rawValue: 9))
        #expect(store.retryCalls.first?.source == "https://example.com/image.png")
    }

    @Test("Provider retry disabled uses protocol state for error affordance")
    func providerRetryDisabledUsesStoreProtocolState() {
        let blockID = BlockIdentity(rawValue: 10)
        let attachment = ImageAttachment(
            blockID: blockID,
            source: "https://example.com/image.png",
            alt: "cover",
            theme: .default
        )
        let store = MockImageLoadStore(
            loadResults: [blockID: .failed],
            retryEnabled: false
        )
        let (provider, _) = makeProvider(for: attachment, store: store)

        provider.loadView()
        let view = provider.view as? ImageBlockView
        let errorControl: UIControl? = view?.firstSubview()
        let retryLabel: UILabel? = view?.firstSubview()

        #expect(errorControl?.isUserInteractionEnabled == false)
        #expect(retryLabel?.text == "Unable to load")
    }
}

private extension ImageAttachmentTests {
    final class MockImageLoadStore: ImageLoadStore, @unchecked Sendable {
        private let aspectRatios: [BlockIdentity: CGFloat]
        private let loadResults: [BlockIdentity: ImageLoadResult]
        private(set) var retryCalls: [(blockID: BlockIdentity, source: String?)] = []
        let retryEnabled: Bool

        init(
            aspectRatios: [BlockIdentity: CGFloat] = [:],
            loadResults: [BlockIdentity: ImageLoadResult] = [:],
            retryEnabled: Bool = true
        ) {
            self.aspectRatios = aspectRatios
            self.loadResults = loadResults
            self.retryEnabled = retryEnabled
        }

        func loadResult(for blockID: BlockIdentity) -> ImageLoadResult? {
            loadResults[blockID]
        }

        func register(sink: any ImageLoadSink, for blockID: BlockIdentity) {}

        func resolvedAspectRatio(for blockID: BlockIdentity) -> CGFloat? {
            aspectRatios[blockID]
        }

        func retryLoad(blockID: BlockIdentity, source: String?) {
            retryCalls.append((blockID, source))
        }

        func unregisterSink(for blockID: BlockIdentity) {}
    }

    func makeProvider(
        for attachment: ImageAttachment,
        store: (any ImageLoadStore)?
    ) -> (ImageAttachmentProvider, any NSTextLocation) {
        attachment.imageLoadStore = store
        let layoutManager = NSTextLayoutManager()
        let location = layoutManager.documentRange.location

        let provider = ImageAttachmentProvider(
            textAttachment: attachment,
            parentView: nil,
            textLayoutManager: layoutManager,
            location: location
        )

        return (provider, location)
    }
}
