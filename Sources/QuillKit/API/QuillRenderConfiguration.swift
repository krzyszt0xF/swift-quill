import CoreGraphics
import Foundation

public enum StreamingMode: String, CaseIterable, Sendable {
    case bufferedModules
    case hybridTail
    case stableBlocks
}

enum PerformanceProfile: String, CaseIterable, Sendable {
    case balanced
    case longForm
    case snappy
}

struct QuillRenderConfiguration: Equatable, Sendable {
    var streamingMode: StreamingMode
    var performanceProfile: PerformanceProfile
    var typewriter: TypewriterConfiguration
    var layout: LayoutConfiguration
    var tail: TailConfiguration
    var bufferedStream: BufferedStreamConfiguration

    init(
        streamingMode: StreamingMode = .hybridTail,
        performanceProfile: PerformanceProfile = .balanced,
        typewriter: TypewriterConfiguration = .balanced,
        layout: LayoutConfiguration = .default,
        tail: TailConfiguration = .default,
        bufferedStream: BufferedStreamConfiguration = .default
    ) {
        self.streamingMode = streamingMode
        self.performanceProfile = performanceProfile
        self.typewriter = typewriter
        self.layout = layout
        self.tail = tail
        self.bufferedStream = bufferedStream
    }
}

struct BufferedStreamConfiguration: Equatable, Sendable {
    var minModuleLength: Int
    var maxBufferingDelay: TimeInterval

    init(
        minModuleLength: Int = 50,
        maxBufferingDelay: TimeInterval = 1.5
    ) {
        self.minModuleLength = max(1, minModuleLength)
        self.maxBufferingDelay = max(0.1, maxBufferingDelay)
    }

    static var `default`: Self { Self() }
}

struct TypewriterConfiguration: Equatable, Sendable {
    struct QueueTiming: Equatable, Sendable {
        var charsPerStep: Int
        var baseDuration: TimeInterval
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
}

struct LayoutConfiguration: Equatable, Sendable {
    var heightMeasurementCoalescingInterval: TimeInterval
    var heightNotificationMinimumDelta: CGFloat

    init(
        heightMeasurementCoalescingInterval: TimeInterval,
        heightNotificationMinimumDelta: CGFloat = 8
    ) {
        self.heightMeasurementCoalescingInterval = max(0, heightMeasurementCoalescingInterval)
        self.heightNotificationMinimumDelta = max(0, heightNotificationMinimumDelta)
    }

    static var `default`: Self {
        Self(
            heightMeasurementCoalescingInterval: 0.016,
            heightNotificationMinimumDelta: 8
        )
    }

    static var snappy: Self {
        Self(
            heightMeasurementCoalescingInterval: 0.010,
            heightNotificationMinimumDelta: 4
        )
    }

    static var longForm: Self {
        Self(
            heightMeasurementCoalescingInterval: 0.020,
            heightNotificationMinimumDelta: 10
        )
    }
}

struct TailConfiguration: Equatable, Sendable {
    var animateFlowTailText: Bool
    var flowTailCharsPerStep: Int
    var flowTailBaseDuration: TimeInterval
    var flowTailCommaPause: TimeInterval
    var flowTailSentencePause: TimeInterval
    var flowTailStartBufferCharacters: Int
    var flowTailMaxStartDelay: TimeInterval
    var flowTailIdleTimeout: TimeInterval
    var flowTailJitterMax: TimeInterval
    var flowTailRevealInitialAlpha: CGFloat
    var flowTailRevealFadeDuration: TimeInterval
    var flowTailUpdateCoalescingInterval: TimeInterval
    var reuseFlowTailView: Bool
    var reuseCodeTailView: Bool

    init(
        animateFlowTailText: Bool = true,
        flowTailCharsPerStep: Int = 6,
        flowTailBaseDuration: TimeInterval = 0.012,
        flowTailCommaPause: TimeInterval = 0.030,
        flowTailSentencePause: TimeInterval = 0.080,
        flowTailStartBufferCharacters: Int = 48,
        flowTailMaxStartDelay: TimeInterval = 0.80,
        flowTailIdleTimeout: TimeInterval = 1.20,
        flowTailJitterMax: TimeInterval = 0.005,
        flowTailRevealInitialAlpha: CGFloat = 1,
        flowTailRevealFadeDuration: TimeInterval = 0,
        flowTailUpdateCoalescingInterval: TimeInterval = 0.05,
        reuseFlowTailView: Bool = true,
        reuseCodeTailView: Bool = true
    ) {
        self.animateFlowTailText = animateFlowTailText
        self.flowTailCharsPerStep = max(1, flowTailCharsPerStep)
        self.flowTailBaseDuration = max(0.001, flowTailBaseDuration)
        self.flowTailCommaPause = max(0, flowTailCommaPause)
        self.flowTailSentencePause = max(0, flowTailSentencePause)
        self.flowTailStartBufferCharacters = max(0, flowTailStartBufferCharacters)
        self.flowTailMaxStartDelay = max(0, flowTailMaxStartDelay)
        self.flowTailIdleTimeout = max(0.05, flowTailIdleTimeout)
        self.flowTailJitterMax = max(0, flowTailJitterMax)
        self.flowTailRevealInitialAlpha = min(max(0, flowTailRevealInitialAlpha), 1)
        self.flowTailRevealFadeDuration = max(0, flowTailRevealFadeDuration)
        self.flowTailUpdateCoalescingInterval = max(0, flowTailUpdateCoalescingInterval)
        self.reuseFlowTailView = reuseFlowTailView
        self.reuseCodeTailView = reuseCodeTailView
    }

    static var `default`: Self { Self() }
}
