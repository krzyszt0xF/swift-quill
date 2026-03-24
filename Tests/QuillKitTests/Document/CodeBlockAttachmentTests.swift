@testable import QuillKit
import QuillCore
import Foundation
import Testing
import UIKit

@MainActor
@Suite("CodeBlockAttachment")
struct CodeBlockAttachmentTests {
    @Test("Attachment stores blockID, language, and code")
    func identityAndPayload() {
        let id = BlockIdentity(rawValue: 1)
        let attachment = CodeBlockAttachment(blockID: id, language: "swift", code: "let x = 1")

        #expect(attachment.blockID == id)
        #expect(attachment.language == "swift")
        #expect(attachment.code == "let x = 1")
    }

    @Test("Attachment with nil language stores nil")
    func nilLanguage() {
        let attachment = CodeBlockAttachment(blockID: BlockIdentity(rawValue: 2), language: nil, code: "plain")

        #expect(attachment.language == nil)
        #expect(attachment.code == "plain")
    }

    @Test("Attachment allows text attachment view")
    func allowsViewProvider() {
        let attachment = CodeBlockAttachment(blockID: BlockIdentity(rawValue: 2), language: "swift", code: "code")

        #expect(attachment.allowsTextAttachmentView == true)
    }

    @Test("Attachment appearance animation is consumed only once")
    func appearanceAnimationConsumption() {
        let attachment = CodeBlockAttachment(blockID: BlockIdentity(rawValue: 3), language: "swift", code: "code")

        #expect(attachment.consumePendingAppearanceAnimation(isReduceMotionEnabled: false))
        #expect(attachment.consumePendingAppearanceAnimation(isReduceMotionEnabled: false) == false)
    }

    @Test("Attachment appearance animation respects reduce motion")
    func appearanceAnimationRespectsReduceMotion() {
        let attachment = CodeBlockAttachment(blockID: BlockIdentity(rawValue: 4), language: "swift", code: "code")

        #expect(attachment.consumePendingAppearanceAnimation(isReduceMotionEnabled: true) == false)
    }

    @Test("Provider sets tracksTextAttachmentViewBounds")
    func providerConfiguration() {
        let attachment = CodeBlockAttachment(blockID: BlockIdentity(rawValue: 2), language: "swift", code: "let x = 1")
        let layoutManager = NSTextLayoutManager()
        let location = layoutManager.documentRange.location

        let provider = CodeBlockAttachmentProvider(
            textAttachment: attachment,
            parentView: nil,
            textLayoutManager: layoutManager,
            location: location
        )

        #expect(provider.tracksTextAttachmentViewBounds == true)
    }

    @Test("Provider returns width-driven bounds from proposed line fragment")
    func widthDrivenBounds() {
        let attachment = CodeBlockAttachment(blockID: BlockIdentity(rawValue: 2), language: "swift", code: "let x = 1")
        let layoutManager = NSTextLayoutManager()
        let location = layoutManager.documentRange.location

        let provider = CodeBlockAttachmentProvider(
            textAttachment: attachment,
            parentView: nil,
            textLayoutManager: layoutManager,
            location: location
        )

        provider.loadView()

        let proposedFragment = CGRect(x: 0, y: 0, width: 300, height: 1000)
        let bounds = provider.attachmentBounds(
            for: [:],
            location: location,
            textContainer: nil,
            proposedLineFragment: proposedFragment,
            position: .zero
        )

        #expect(bounds.width == 300)
        #expect(bounds.height > 0)
    }

    @Test("Provider returns safe bounds before loadView")
    func safeBoundsBeforeLoadView() {
        let attachment = CodeBlockAttachment(blockID: BlockIdentity(rawValue: 2), language: "swift", code: "let x = 1")
        let layoutManager = NSTextLayoutManager()
        let location = layoutManager.documentRange.location

        let provider = CodeBlockAttachmentProvider(
            textAttachment: attachment,
            parentView: nil,
            textLayoutManager: layoutManager,
            location: location
        )

        let proposedFragment = CGRect(x: 0, y: 0, width: 300, height: 1000)
        let bounds = provider.attachmentBounds(
            for: [:],
            location: location,
            textContainer: nil,
            proposedLineFragment: proposedFragment,
            position: .zero
        )

        #expect(bounds.width == 300)
        #expect(bounds.height > 0)
    }

    @Test("Provider returns fallback bounds for zero-width proposed fragment")
    func fallbackBoundsForZeroWidth() {
        let attachment = CodeBlockAttachment(blockID: BlockIdentity(rawValue: 2), language: "swift", code: "code")
        let layoutManager = NSTextLayoutManager()
        let location = layoutManager.documentRange.location

        let provider = CodeBlockAttachmentProvider(
            textAttachment: attachment,
            parentView: nil,
            textLayoutManager: layoutManager,
            location: location
        )

        let proposedFragment = CGRect(x: 0, y: 0, width: 0, height: 0)
        let bounds = provider.attachmentBounds(
            for: [:],
            location: location,
            textContainer: nil,
            proposedLineFragment: proposedFragment,
            position: .zero
        )

        #expect(bounds.width > 0)
        #expect(bounds.height > 0)
    }
}
