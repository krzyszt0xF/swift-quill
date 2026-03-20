import Foundation

struct TypewriterConfiguration: Equatable, Sendable {
    var lowQueue: QueueTiming
    var mediumQueue: QueueTiming
    var highQueue: QueueTiming
    var mediumQueueLowerBound: Int
    var highQueueLowerBound: Int
    var commaPause: TimeInterval
    var sentencePause: TimeInterval
    var jitterMax: TimeInterval
    var textRevealInitialAlpha: CGFloat
    var textRevealFadeDuration: TimeInterval
    
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
        textRevealFadeDuration: TimeInterval = 0.08) {
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
    
    struct QueueTiming: Equatable, Sendable {
        var charsPerStep: Int
        var baseDuration: TimeInterval
        var elementGapDuration: TimeInterval
        
        init(
            charsPerStep: Int,
            baseDuration: TimeInterval,
            elementGapDuration: TimeInterval) {
                self.charsPerStep = charsPerStep
                self.baseDuration = baseDuration
                self.elementGapDuration = elementGapDuration
            }
    }
}

extension TypewriterConfiguration {
    static var snappy: Self {
        Self(
            lowQueue: .init(charsPerStep: 7, baseDuration: 0.010, elementGapDuration: 0.020),
            mediumQueue: .init(charsPerStep: 9, baseDuration: 0.008, elementGapDuration: 0.014),
            highQueue: .init(charsPerStep: 12, baseDuration: 0.006, elementGapDuration: 0.008),
            commaPause: 0.010,
            sentencePause: 0.030,
            jitterMax: 0.003
        )
    }
    
    static var balanced: Self {
        Self(
            lowQueue: .init(charsPerStep: 6, baseDuration: 0.012, elementGapDuration: 0.030),
            mediumQueue: .init(charsPerStep: 8, baseDuration: 0.010, elementGapDuration: 0.020),
            highQueue: .init(charsPerStep: 10, baseDuration: 0.008, elementGapDuration: 0.012),
            commaPause: 0.015,
            sentencePause: 0.045,
            jitterMax: 0.005
        )
    }
    
    static var longForm: Self {
        Self(
            lowQueue: .init(charsPerStep: 5, baseDuration: 0.016, elementGapDuration: 0.050),
            mediumQueue: .init(charsPerStep: 6, baseDuration: 0.014, elementGapDuration: 0.040),
            highQueue: .init(charsPerStep: 8, baseDuration: 0.010, elementGapDuration: 0.025),
            commaPause: 0.020,
            sentencePause: 0.060,
            jitterMax: 0.006
        )
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

private extension TypewriterConfiguration.QueueTiming {
    func scaled(by speed: Double) -> Self {
        Self(
            charsPerStep: max(1, Int((Double(charsPerStep) * speed).rounded())),
            baseDuration: baseDuration / speed,
            elementGapDuration: elementGapDuration / speed)
    }
}
