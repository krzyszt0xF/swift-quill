@testable import QuillKit
import Foundation
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("TailAnimator", GloballySerialized(), .tags(.rendering, .streaming))
struct TailAnimatorTests {
    @Test("Advance presentation leaves frozen prefix untouched")
    func advancePresentationDoesNotTouchFrozenPrefix() throws {
        let animator = TailAnimator(isReduceMotionEnabled: { false })
        let textView = DocumentTextView()
        let contentStorage = try #require(textView.contentStorage)
        let prefix = NSAttributedString(
            string: "Frozen ",
            attributes: [.foregroundColor: UIColor.label]
        )
        let tail = NSAttributedString(
            string: "Tail",
            attributes: [.foregroundColor: UIColor.label]
        )
        let batch = NSAttributedString(
            string: " fade",
            attributes: [.foregroundColor: UIColor.label]
        )

        _ = animator.rebaseVisibleContent(to: tail, tailStart: prefix.length, now: 0)
        let presentedBatch = animator.prepareBatchForAppend(
            batch,
            policy: makePolicy(initialAlpha: 0.2, fadeDuration: 1.0),
            now: 0
        )

        let document = NSMutableAttributedString(attributedString: prefix)
        document.append(tail)
        document.append(presentedBatch)

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: NSRange(location: 0, length: 0),
                with: document
            )
        }

        let stillAnimating = animator.advancePresentation(
            in: contentStorage,
            now: 0.5
        )
        let rendered = try #require(contentStorage.attributedString)

        #expect(stillAnimating)
        #expect(isApproximatelyEqual(alpha(at: 0, in: rendered), 1))
        #expect(alpha(at: prefix.length + tail.length, in: rendered) > 0.2)
        #expect(alpha(at: prefix.length + tail.length, in: rendered) < 1)
    }

    @Test("Prepared batch starts at configured initial alpha")
    func preparedBatchStartsFaded() {
        let animator = TailAnimator(isReduceMotionEnabled: { false })
        let tail = NSAttributedString(
            string: "Tail",
            attributes: [.foregroundColor: UIColor.label]
        )
        let batch = NSAttributedString(
            string: " fade",
            attributes: [.foregroundColor: UIColor.label]
        )

        _ = animator.rebaseVisibleContent(to: tail, tailStart: 0, now: 0)
        let presentedBatch = animator.prepareBatchForAppend(
            batch,
            policy: makePolicy(initialAlpha: 0.25, fadeDuration: 1.0),
            now: 0
        )

        #expect(animator.activeSegmentCount == 1)
        #expect(isApproximatelyEqual(alpha(at: 0, in: presentedBatch), 0.25))
    }

    @Test("Rebase drops segments beyond the common prefix")
    func rebaseDropsOutdatedSegments() {
        let animator = TailAnimator(isReduceMotionEnabled: { false })
        let policy = makePolicy(initialAlpha: 0.2, fadeDuration: 1.0)
        let originalVisible = NSAttributedString(
            string: "abcdef",
            attributes: [.foregroundColor: UIColor.label]
        )
        let batch = NSAttributedString(
            string: "gh",
            attributes: [.foregroundColor: UIColor.label]
        )
        let rebasedVisible = NSAttributedString(
            string: "abcXYZ",
            attributes: [.foregroundColor: UIColor.label]
        )

        _ = animator.rebaseVisibleContent(to: originalVisible, tailStart: 0, now: 0)
        _ = animator.prepareBatchForAppend(batch, policy: policy, now: 0)
        let presented = animator.rebaseVisibleContent(
            to: rebasedVisible,
            tailStart: 0,
            now: 0.1
        )

        #expect(animator.activeSegmentCount == 0)
        #expect(isApproximatelyEqual(alpha(at: 3, in: presented), 1))
    }
}

private extension TailAnimatorTests {
    func alpha(
        at index: Int,
        in attributedString: NSAttributedString
    ) -> CGFloat {
        let color = attributedString.attribute(
            .foregroundColor,
            at: index,
            effectiveRange: nil
        ) as? UIColor

        return color?
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            .cgColor
            .alpha ?? 1
    }

    func isApproximatelyEqual(
        _ lhs: CGFloat,
        _ rhs: CGFloat,
        tolerance: CGFloat = 0.001
    ) -> Bool {
        abs(lhs - rhs) <= tolerance
    }

    func makePolicy(
        initialAlpha: CGFloat,
        fadeDuration: TimeInterval
    ) -> TailRevealPolicy {
        TailRevealPolicy(
            lowQueue: .init(charsPerStep: 2, baseDuration: 0.008, elementGapDuration: 0.014),
            mediumQueue: .init(charsPerStep: 3, baseDuration: 0.007, elementGapDuration: 0.010),
            highQueue: .init(charsPerStep: 4, baseDuration: 0.005, elementGapDuration: 0.008),
            commaPause: 0.012,
            sentencePause: 0.038,
            jitterMax: 0,
            textRevealInitialAlpha: initialAlpha,
            textRevealFadeDuration: fadeDuration
        )
    }
}
