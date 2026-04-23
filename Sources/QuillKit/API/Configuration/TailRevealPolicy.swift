// Internal configuration; not part of public API despite the API/ path segment.
// Scheduled for relocation post-1.0.0 (see Docs/ExternalAudit.md).

import Foundation

struct TailRevealPolicy: Equatable, Sendable {
    var commaPause: TimeInterval
    var highQueue: TailRevealPolicy.QueueTiming
    var highQueueLowerBound: Int
    var jitterMax: TimeInterval
    var lowQueue: TailRevealPolicy.QueueTiming
    var mediumQueue: TailRevealPolicy.QueueTiming
    var mediumQueueLowerBound: Int
    var sentencePause: TimeInterval
    var textRevealFadeDuration: TimeInterval
    var textRevealInitialAlpha: CGFloat

    init(
        lowQueue: QueueTiming,
        mediumQueue: QueueTiming,
        highQueue: QueueTiming,
        mediumQueueLowerBound: Int = 4,
        highQueueLowerBound: Int = 9,
        commaPause: TimeInterval,
        sentencePause: TimeInterval,
        jitterMax: TimeInterval = 0.005,
        textRevealInitialAlpha: CGFloat = 0.2,
        textRevealFadeDuration: TimeInterval = 0.08
    ) {
        self.lowQueue = lowQueue
        self.mediumQueue = mediumQueue
        self.highQueue = highQueue
        self.mediumQueueLowerBound = max(1, mediumQueueLowerBound)
        self.highQueueLowerBound = max(self.mediumQueueLowerBound + 1, highQueueLowerBound)
        self.commaPause = max(0, commaPause)
        self.sentencePause = max(0, sentencePause)
        self.jitterMax = max(0, jitterMax)
        self.textRevealInitialAlpha = min(max(0, textRevealInitialAlpha), 1)
        self.textRevealFadeDuration = max(0, textRevealFadeDuration)
    }
}

extension TailRevealPolicy {
    static var balanced: Self {
        Self(
            lowQueue: .init(charsPerStep: 2, baseDuration: 0.008, elementGapDuration: 0.014),
            mediumQueue: .init(charsPerStep: 3, baseDuration: 0.007, elementGapDuration: 0.010),
            highQueue: .init(charsPerStep: 4, baseDuration: 0.005, elementGapDuration: 0.008),
            commaPause: 0.012,
            sentencePause: 0.038,
            jitterMax: 0.005
        )
    }

    static var longForm: Self {
        Self(
            lowQueue: .init(charsPerStep: 2, baseDuration: 0.010, elementGapDuration: 0.018),
            mediumQueue: .init(charsPerStep: 3, baseDuration: 0.008, elementGapDuration: 0.014),
            highQueue: .init(charsPerStep: 4, baseDuration: 0.006, elementGapDuration: 0.010),
            commaPause: 0.016,
            sentencePause: 0.050,
            jitterMax: 0.006
        )
    }

    static var snappy: Self {
        Self(
            lowQueue: .init(charsPerStep: 3, baseDuration: 0.006, elementGapDuration: 0.012),
            mediumQueue: .init(charsPerStep: 4, baseDuration: 0.005, elementGapDuration: 0.010),
            highQueue: .init(charsPerStep: 5, baseDuration: 0.004, elementGapDuration: 0.007),
            commaPause: 0.008,
            sentencePause: 0.025,
            jitterMax: 0.003
        )
    }

    func fallbackBurstSize(forRemainingLength remainingLength: Int) -> Int {
        makeQueueTiming(forRemainingLength: remainingLength).charsPerStep
    }

    func punctuationDelay(after character: Character?) -> TimeInterval {
        guard let character else { return 0 }

        if ",，、".contains(character) {
            return commaPause
        }

        if ".。！？!?;；\n".contains(character) {
            return sentencePause
        }

        return 0
    }

    func revealInterval(
        forRemainingLength remainingLength: Int,
        lastRevealedCharacter: Character?
    ) -> TimeInterval {
        let queueTiming = makeQueueTiming(forRemainingLength: remainingLength)
        return makeBurstRevealInterval(for: queueTiming)
            + punctuationDelay(after: lastRevealedCharacter)
    }

    func scaled(by speed: Double) -> Self {
        Self(
            lowQueue: lowQueue.scaled(by: speed),
            mediumQueue: mediumQueue.scaled(by: speed),
            highQueue: highQueue.scaled(by: speed),
            mediumQueueLowerBound: mediumQueueLowerBound,
            highQueueLowerBound: highQueueLowerBound,
            commaPause: commaPause / speed,
            sentencePause: sentencePause / speed,
            jitterMax: jitterMax,
            textRevealInitialAlpha: textRevealInitialAlpha,
            textRevealFadeDuration: textRevealFadeDuration
        )
    }
}

extension TailRevealPolicy {
    struct QueueTiming: Equatable, Sendable {
        var baseDuration: TimeInterval
        var charsPerStep: Int
        var elementGapDuration: TimeInterval

        init(
            charsPerStep: Int,
            baseDuration: TimeInterval,
            elementGapDuration: TimeInterval
        ) {
            self.charsPerStep = charsPerStep
            self.baseDuration = baseDuration
            self.elementGapDuration = elementGapDuration
        }
    }
}

private extension TailRevealPolicy {
    func makeBurstRevealInterval(for queueTiming: QueueTiming) -> TimeInterval {
        queueTiming.elementGapDuration + (queueTiming.baseDuration * Double(queueTiming.charsPerStep))
    }

    func makeQueueTiming(forRemainingLength remainingLength: Int) -> QueueTiming {
        if remainingLength >= highQueueLowerBound {
            return highQueue
        }

        if remainingLength >= mediumQueueLowerBound {
            return mediumQueue
        }

        return lowQueue
    }
}

private extension TailRevealPolicy.QueueTiming {
    func scaled(by speed: Double) -> Self {
        Self(
            charsPerStep: max(1, Int((Double(charsPerStep) * speed).rounded())),
            baseDuration: baseDuration / speed,
            elementGapDuration: elementGapDuration / speed
        )
    }
}
