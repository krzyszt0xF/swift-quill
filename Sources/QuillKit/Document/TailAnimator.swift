import QuartzCore
import UIKit

@MainActor
final class TailAnimator {
    var activeSegmentCount: Int {
        segments.count
    }

    var hasActiveSegments: Bool {
        segments.isEmpty == false
    }

    private let isReduceMotionEnabled: () -> Bool
    private var segments: [TailAnimatorSegment] = []
    private var tailContent = NSAttributedString()
    private var tailStart: Int?

    init(isReduceMotionEnabled: @escaping () -> Bool = { UIAccessibility.isReduceMotionEnabled }) {
        self.isReduceMotionEnabled = isReduceMotionEnabled
    }

    func advancePresentation(
        in contentStorage: NSTextContentStorage,
        now: CFTimeInterval = CACurrentMediaTime()
    ) -> Bool {
        guard let tailStart else {
            cancel()
            return false
        }

        removeEmptySegments()
        guard segments.isEmpty == false else { return false }

        let currentLength = contentStorage.attributedString?.length ?? 0
        let updates = makeColorUpdates(at: now, currentLength: currentLength, tailStart: tailStart)
        guard updates.isEmpty == false else {
            segments.removeAll()
            return false
        }

        contentStorage.performEditingTransaction {
            for update in updates {
                contentStorage.textStorage?.addAttribute(
                    .foregroundColor,
                    value: update.color,
                    range: update.range
                )
            }
        }

        removeCompletedSegments(at: now)
        return hasActiveSegments
    }

    func cancel() {
        segments.removeAll()
        tailContent = NSAttributedString()
        tailStart = nil
    }

    func prepareBatchForAppend(
        _ batch: NSAttributedString,
        policy: TailRevealPolicy,
        now: CFTimeInterval = CACurrentMediaTime()
    ) -> NSAttributedString {
        let batchStart = tailContent.length
        tailContent = makeTailContent(byAppending: batch)

        guard let segment = makeSegment(
            from: batch,
            batchStart: batchStart,
            policy: policy,
            now: now
        ) else {
            return batch
        }

        segments.append(segment)
        return makePresentedContent(
            from: batch,
            now: now,
            offset: batchStart
        )
    }

    func rebaseVisibleContent(
        to content: NSAttributedString,
        tailStart: Int,
        now: CFTimeInterval = CACurrentMediaTime()
    ) -> NSAttributedString {
        let commonPrefixLength = makeCommonPrefixLength(
            lhs: tailContent.string as NSString,
            rhs: content.string as NSString
        )

        self.tailContent = content
        self.tailStart = tailStart
        segments = segments.compactMap { $0.clamped(toMaximumLength: commonPrefixLength) }
        removeCompletedSegments(at: now)

        return makePresentedContent(from: content, now: now)
    }
}

private extension TailAnimator {
    func makeAlpha(
        for segment: TailAnimatorSegment,
        now: CFTimeInterval
    ) -> CGFloat {
        let progress = now.progress(
            duration: segment.duration,
            startTime: segment.startTime
        )
        return segment.initialAlpha + ((1 - segment.initialAlpha) * progress)
    }

    func makeColorUpdates(
        at now: CFTimeInterval,
        currentLength: Int,
        tailStart: Int
    ) -> [TailAnimatorColorUpdate] {
        var updates: [TailAnimatorColorUpdate] = []

        for segment in segments {
            let alpha = makeAlpha(for: segment, now: now)
            for colorRun in segment.colorRuns {
                let range = NSRange(
                    location: tailStart + colorRun.range.location,
                    length: colorRun.range.length
                )
                guard range.location >= tailStart else {
                    assertionFailure("Tail animator attempted to touch the frozen prefix.")
                    continue
                }
                guard range.location + range.length <= currentLength else { continue }

                updates.append(
                    TailAnimatorColorUpdate(
                        color: colorRun.color.makeColor(alpha: alpha),
                        range: range
                    )
                )
            }
        }

        return updates
    }

    func makeCommonPrefixLength(
        lhs: NSString,
        rhs: NSString
    ) -> Int {
        let limit = min(lhs.length, rhs.length)
        var index = 0

        while index < limit, lhs.character(at: index) == rhs.character(at: index) {
            index += 1
        }

        return index
    }

    func makePresentedContent(
        from content: NSAttributedString,
        now: CFTimeInterval,
        offset: Int = 0
    ) -> NSAttributedString {
        guard segments.isEmpty == false else { return content }

        let result = NSMutableAttributedString(attributedString: content)
        let absoluteRange = NSRange(location: offset, length: content.length)

        for segment in segments {
            let alpha = makeAlpha(for: segment, now: now)

            for colorRun in segment.colorRuns {
                let intersection = NSIntersectionRange(colorRun.range, absoluteRange)
                guard intersection.length > 0 else { continue }

                result.addAttribute(
                    .foregroundColor,
                    value: colorRun.color.makeColor(alpha: alpha),
                    range: NSRange(
                        location: intersection.location - offset,
                        length: intersection.length
                    )
                )
            }
        }

        return result
    }

    func makeSegment(
        from batch: NSAttributedString,
        batchStart: Int,
        policy: TailRevealPolicy,
        now: CFTimeInterval
    ) -> TailAnimatorSegment? {
        guard batch.length > 0,
              policy.textRevealFadeDuration > 0,
              policy.textRevealInitialAlpha < 1,
              isReduceMotionEnabled() == false
        else { return nil }

        let colorRuns = batch.makeColorRuns(offset: batchStart)
        guard colorRuns.isEmpty == false else { return nil }

        return TailAnimatorSegment(
            colorRuns: colorRuns,
            duration: policy.textRevealFadeDuration,
            initialAlpha: policy.textRevealInitialAlpha,
            range: NSRange(location: batchStart, length: batch.length),
            startTime: now
        )
    }

    func makeTailContent(byAppending batch: NSAttributedString) -> NSAttributedString {
        let combined = NSMutableAttributedString(attributedString: tailContent)
        combined.append(batch)
        return combined
    }

    func removeCompletedSegments(at now: CFTimeInterval) {
        segments.removeAll { segment in
            now.isComplete(
                duration: segment.duration,
                startTime: segment.startTime
            )
        }
    }

    func removeEmptySegments() {
        segments.removeAll { segment in
            segment.range.length == 0
        }
    }
}

private struct TailAnimatorColorRun {
    let color: UIColor
    let range: NSRange
}

private struct TailAnimatorColorUpdate {
    let color: UIColor
    let range: NSRange
}

private struct TailAnimatorSegment {
    let colorRuns: [TailAnimatorColorRun]
    let duration: TimeInterval
    let initialAlpha: CGFloat
    let range: NSRange
    let startTime: CFTimeInterval
}

private extension CFTimeInterval {
    func isComplete(
        duration: TimeInterval,
        startTime: CFTimeInterval
    ) -> Bool {
        progress(duration: duration, startTime: startTime) >= 1
    }

    func progress(
        duration: TimeInterval,
        startTime: CFTimeInterval
    ) -> CGFloat {
        guard duration > 0 else { return 1 }

        let elapsed = max(0, self - startTime)
        return min(1, CGFloat(elapsed / duration))
    }
}

private extension NSAttributedString {
    func makeColorRuns(offset: Int) -> [TailAnimatorColorRun] {
        let fullRange = NSRange(location: 0, length: length)
        var colorRuns: [TailAnimatorColorRun] = []

        enumerateAttributes(in: fullRange) { attributes, range, _ in
            guard attributes[.attachment] == nil,
                  let color = attributes[.foregroundColor] as? UIColor
            else { return }

            colorRuns.append(
                TailAnimatorColorRun(
                    color: color,
                    range: NSRange(location: offset + range.location, length: range.length)
                )
            )
        }

        return colorRuns
    }
}

private extension TailAnimatorColorRun {
    func clamped(to container: NSRange) -> TailAnimatorColorRun? {
        let intersection = NSIntersectionRange(range, container)
        guard intersection.length > 0 else { return nil }

        return TailAnimatorColorRun(
            color: color,
            range: intersection
        )
    }
}

private extension TailAnimatorSegment {
    func clamped(toMaximumLength maximumLength: Int) -> TailAnimatorSegment? {
        guard range.location < maximumLength else { return nil }

        let clampedRange = NSRange(
            location: range.location,
            length: min(range.length, maximumLength - range.location)
        )
        let clampedColorRuns = colorRuns.compactMap { $0.clamped(to: clampedRange) }
        guard clampedColorRuns.isEmpty == false else { return nil }

        return TailAnimatorSegment(
            colorRuns: clampedColorRuns,
            duration: duration,
            initialAlpha: initialAlpha,
            range: clampedRange,
            startTime: startTime
        )
    }
}

private extension UIColor {
    func makeColor(alpha: CGFloat) -> UIColor {
        withAlphaComponent(cgColor.alpha * alpha)
    }
}
