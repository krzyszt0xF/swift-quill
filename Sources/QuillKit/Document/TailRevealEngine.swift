import Foundation

@MainActor
final class TailRevealEngine {
    var onProgress: (() -> Void)?

    private let appendBatch: (NSAttributedString) -> Bool
    private lazy var driver = TailRevealDriver(
        canRevealMore: { [weak self] in
            self?.state?.hasPendingContent ?? false
        },
        intervalProvider: { [weak self] in
            self?.state?.nextInterval ?? Layout.defaultInterval
        },
        revealNextBatch: { [weak self] in
            self?.appendNextBatch() ?? false
        }
    )
    private var state: State?

    init(appendBatch: @escaping (NSAttributedString) -> Bool) {
        self.appendBatch = appendBatch
    }

    func cancel() {
        driver.stop()
        state = nil
    }

    func rebase(
        to content: NSAttributedString,
        policy: TailRevealPolicy
    ) -> NSAttributedString {
        if var currentState = state {
            currentState.rebase(to: content, policy: policy)
            state = currentState
        } else {
            state = State(content: content, policy: policy)
        }

        if state?.hasPendingContent == true {
            driver.resume(immediate: false)
        } else {
            driver.stop()
        }

        return state?.visibleContent ?? NSAttributedString()
    }
}

extension TailRevealEngine {
    static func makeBatchRange(
        content: NSAttributedString,
        visibleLength: Int,
        policy: TailRevealPolicy
    ) -> NSRange? {
        State.makeNextBatchRange(
            content: content,
            visibleLength: visibleLength,
            policy: policy
        )
    }
}

private extension TailRevealEngine {
    enum Layout {
        static let defaultInterval: TimeInterval = 0.05
    }

    @discardableResult
    func appendNextBatch() -> Bool {
        guard var currentState = state else { return false }
        guard let batch = currentState.nextBatch() else {
            state = currentState
            return false
        }

        state = currentState
        guard appendBatch(batch) else {
            cancel()
            return false
        }

        onProgress?()
        return true
    }

    struct State {
        var content: NSAttributedString
        var nextInterval: TimeInterval
        var policy: TailRevealPolicy
        var visibleLength: Int

        private var lastRevealedCharacter: Character?

        init(content: NSAttributedString, policy: TailRevealPolicy) {
            self.content = content
            self.policy = policy
            visibleLength = 0
            lastRevealedCharacter = nil
            nextInterval = policy.revealInterval(
                forRemainingLength: content.length,
                lastRevealedCharacter: nil
            )
        }

        var hasPendingContent: Bool {
            visibleLength < content.length
        }

        var visibleContent: NSAttributedString {
            guard visibleLength > 0 else { return NSAttributedString() }
            return content.attributedSubstring(from: NSRange(location: 0, length: visibleLength))
        }

        mutating func nextBatch() -> NSAttributedString? {
            guard let batchRange = Self.makeNextBatchRange(
                content: content,
                visibleLength: visibleLength,
                policy: policy
            ) else {
                return nil
            }

            let batch = content.attributedSubstring(from: batchRange)
            visibleLength = batchRange.location + batchRange.length
            lastRevealedCharacter = makeCharacter(at: visibleLength - 1)
            nextInterval = policy.revealInterval(
                forRemainingLength: content.length - visibleLength,
                lastRevealedCharacter: lastRevealedCharacter
            )
            return batch
        }

        mutating func rebase(
            to content: NSAttributedString,
            policy: TailRevealPolicy
        ) {
            let commonPrefixLength = makeCommonPrefixLength(
                lhs: self.content.string as NSString,
                rhs: content.string as NSString
            )
            self.content = content
            self.policy = policy
            visibleLength = min(visibleLength, commonPrefixLength, content.length)
            lastRevealedCharacter = makeCharacter(at: visibleLength - 1)
            nextInterval = policy.revealInterval(
                forRemainingLength: self.content.length - visibleLength,
                lastRevealedCharacter: lastRevealedCharacter
            )
        }

        private func makeCharacter(at index: Int) -> Character? {
            guard index >= 0 else { return nil }
            guard let range = Range(NSRange(location: index, length: 1), in: content.string) else {
                return nil
            }
            return content.string[range].first
        }

        private func makeCommonPrefixLength(lhs: NSString, rhs: NSString) -> Int {
            let limit = min(lhs.length, rhs.length)
            var index = 0

            while index < limit, lhs.character(at: index) == rhs.character(at: index) {
                index += 1
            }

            return index
        }

        static func makeNextBatchRange(
            content: NSAttributedString,
            visibleLength: Int,
            policy: TailRevealPolicy
        ) -> NSRange? {
            guard visibleLength < content.length else { return nil }

            let string = content.string as NSString
            let remainingLength = content.length - visibleLength
            let preferredBurstSize = policy.fallbackBurstSize(forRemainingLength: remainingLength)
            let preferredEnd = min(string.length, visibleLength + preferredBurstSize)
            let maximumWordBoundaryExtension = min(3, max(1, preferredBurstSize - 1))

            var batchEnd = preferredEnd

            if let wordBoundary = makeNextWordBoundary(
                in: string,
                visibleLength: visibleLength
            ),
               wordBoundary >= preferredEnd,
               wordBoundary <= min(string.length, preferredEnd + maximumWordBoundaryExtension) {
                batchEnd = wordBoundary
            }

            while batchEnd < string.length,
                  let scalar = UnicodeScalar(string.character(at: batchEnd)),
                  CharacterSet.whitespacesAndNewlines.contains(scalar) {
                batchEnd += 1
            }

            return NSRange(location: visibleLength, length: batchEnd - visibleLength)
        }

        private static func makeNextWordBoundary(
            in string: NSString,
            visibleLength: Int
        ) -> Int? {
            guard visibleLength < string.length else { return nil }

            let searchRange = NSRange(location: visibleLength, length: string.length - visibleLength)
            var boundary: Int?

            string.enumerateSubstrings(
                in: searchRange,
                options: [.byWords, .localized, .substringNotRequired]
            ) { _, wordRange, _, stop in
                guard wordRange.location != NSNotFound else { return }

                var end = wordRange.location + wordRange.length
                while end < string.length,
                      let scalar = UnicodeScalar(string.character(at: end)),
                      CharacterSet.whitespacesAndNewlines.contains(scalar) {
                    end += 1
                }

                boundary = end
                stop.pointee = true
            }

            return boundary
        }
    }
}
