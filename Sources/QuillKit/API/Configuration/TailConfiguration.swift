import Foundation

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
        reuseCodeTailView: Bool = true) {
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
}

extension TailConfiguration {
    static let `default` = Self(aggressiveness: .balanced)
    
    init(aggressiveness: TailAggressiveness) {
        switch aggressiveness {
        case .aggressive:
            self = TailConfiguration(
                flowTailBaseDuration: 0.024,
                flowTailStartBufferCharacters: 56,
                flowTailMaxStartDelay: 0.7,
                flowTailIdleTimeout: 1.0,
                flowTailUpdateCoalescingInterval: 0.04
            )
        case .balanced:
            self = TailConfiguration()
        case .conservative:
            self = TailConfiguration(
                flowTailBaseDuration: 0.038,
                flowTailStartBufferCharacters: 96,
                flowTailMaxStartDelay: 1.4,
                flowTailIdleTimeout: 1.8,
                flowTailUpdateCoalescingInterval: 0.06
            )
        }
    }
}
