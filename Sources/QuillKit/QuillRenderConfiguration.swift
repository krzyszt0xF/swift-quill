import Foundation

public enum StreamingMode: String, CaseIterable, Sendable {
    case stableBlocks
    case hybridTail

    public var displayName: String {
        switch self {
        case .stableBlocks:
            return "Stable Blocks"
        case .hybridTail:
            return "Hybrid Tail"
        }
    }
}

public enum PerformanceProfile: String, CaseIterable, Sendable {
    case snappy
    case balanced
    case longForm

    public var displayName: String {
        switch self {
        case .snappy:
            return "Snappy"
        case .balanced:
            return "Balanced"
        case .longForm:
            return "Long Form"
        }
    }
}

public struct QuillRenderConfiguration: Equatable, Sendable {
    public var streamingMode: StreamingMode
    public var performanceProfile: PerformanceProfile
    public var typewriter: TypewriterConfiguration
    public var layout: LayoutConfiguration
    public var tail: TailConfiguration

    public init(
        streamingMode: StreamingMode = .hybridTail,
        performanceProfile: PerformanceProfile = .balanced,
        typewriter: TypewriterConfiguration = .balanced,
        layout: LayoutConfiguration = .default,
        tail: TailConfiguration = .default
    ) {
        self.streamingMode = streamingMode
        self.performanceProfile = performanceProfile
        self.typewriter = typewriter
        self.layout = layout
        self.tail = tail
    }
}

public struct TypewriterConfiguration: Equatable, Sendable {
    public struct QueueTiming: Equatable, Sendable {
        public var charsPerStep: Int
        public var baseDuration: TimeInterval
        public var elementGapDuration: TimeInterval

        public init(
            charsPerStep: Int,
            baseDuration: TimeInterval,
            elementGapDuration: TimeInterval
        ) {
            self.charsPerStep = charsPerStep
            self.baseDuration = baseDuration
            self.elementGapDuration = elementGapDuration
        }
    }

    public var lowQueue: QueueTiming
    public var mediumQueue: QueueTiming
    public var highQueue: QueueTiming
    public var mediumQueueLowerBound: Int
    public var highQueueLowerBound: Int
    public var commaPause: TimeInterval
    public var sentencePause: TimeInterval
    public var jitterMax: TimeInterval

    public init(
        lowQueue: QueueTiming,
        mediumQueue: QueueTiming,
        highQueue: QueueTiming,
        mediumQueueLowerBound: Int = 4,
        highQueueLowerBound: Int = 9,
        commaPause: TimeInterval,
        sentencePause: TimeInterval,
        jitterMax: TimeInterval = 0.005
    ) {
        self.lowQueue = lowQueue
        self.mediumQueue = mediumQueue
        self.highQueue = highQueue
        self.mediumQueueLowerBound = max(1, mediumQueueLowerBound)
        self.highQueueLowerBound = max(self.mediumQueueLowerBound + 1, highQueueLowerBound)
        self.commaPause = max(0, commaPause)
        self.sentencePause = max(0, sentencePause)
        self.jitterMax = max(0, jitterMax)
    }

    public static var snappy: Self {
        Self(
            lowQueue: .init(charsPerStep: 7, baseDuration: 0.010, elementGapDuration: 0.020),
            mediumQueue: .init(charsPerStep: 9, baseDuration: 0.008, elementGapDuration: 0.014),
            highQueue: .init(charsPerStep: 12, baseDuration: 0.006, elementGapDuration: 0.008),
            commaPause: 0.010,
            sentencePause: 0.030,
            jitterMax: 0.003
        )
    }

    public static var balanced: Self {
        Self(
            lowQueue: .init(charsPerStep: 6, baseDuration: 0.012, elementGapDuration: 0.030),
            mediumQueue: .init(charsPerStep: 8, baseDuration: 0.010, elementGapDuration: 0.020),
            highQueue: .init(charsPerStep: 10, baseDuration: 0.008, elementGapDuration: 0.012),
            commaPause: 0.015,
            sentencePause: 0.045,
            jitterMax: 0.005
        )
    }

    public static var longForm: Self {
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

public struct LayoutConfiguration: Equatable, Sendable {
    public var heightMeasurementCoalescingInterval: TimeInterval

    public init(heightMeasurementCoalescingInterval: TimeInterval) {
        self.heightMeasurementCoalescingInterval = max(0, heightMeasurementCoalescingInterval)
    }

    public static var `default`: Self {
        Self(heightMeasurementCoalescingInterval: 0.016)
    }

    public static var snappy: Self {
        Self(heightMeasurementCoalescingInterval: 0.010)
    }

    public static var longForm: Self {
        Self(heightMeasurementCoalescingInterval: 0.020)
    }
}

public struct TailConfiguration: Equatable, Sendable {
    public var animateFlowTailText: Bool
    public var flowTailCharsPerStep: Int
    public var flowTailBaseDuration: TimeInterval
    public var flowTailCommaPause: TimeInterval
    public var flowTailSentencePause: TimeInterval
    public var flowTailStartBufferCharacters: Int
    public var flowTailMaxStartDelay: TimeInterval
    public var reuseFlowTailView: Bool
    public var reuseCodeTailView: Bool

    public init(
        animateFlowTailText: Bool = true,
        flowTailCharsPerStep: Int = 1,
        flowTailBaseDuration: TimeInterval = 0.024,
        flowTailCommaPause: TimeInterval = 0.020,
        flowTailSentencePause: TimeInterval = 0.060,
        flowTailStartBufferCharacters: Int = 18,
        flowTailMaxStartDelay: TimeInterval = 0.28,
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
        self.reuseFlowTailView = reuseFlowTailView
        self.reuseCodeTailView = reuseCodeTailView
    }

    public static var `default`: Self { Self() }
}
