@testable import QuillKit
import Foundation
import Testing

@MainActor
@Suite("Reveal Sequencer Profiles")
struct RevealSequencerProfileTests {
    private static let balancedHighBaseDuration: TimeInterval = 0.008
    private static let balancedLowBaseDuration: TimeInterval = 0.012
    private static let balancedMediumBaseDuration: TimeInterval = 0.010
    private static let timingTolerance: TimeInterval = 0.0001

    @Test("Balanced profile resolves expected queue tiers")
    func balancedProfileResolvesExpectedQueueTiers() {
        let lowQueueTiming = RevealTiming(
            pendingTaskCount: 1,
            typewriterConfiguration: .balanced,
            performanceProfile: .balanced
        )
        let mediumQueueTiming = RevealTiming(
            pendingTaskCount: 4,
            typewriterConfiguration: .balanced,
            performanceProfile: .balanced
        )
        let highQueueTiming = RevealTiming(
            pendingTaskCount: 10,
            typewriterConfiguration: .balanced,
            performanceProfile: .balanced
        )

        #expect(lowQueueTiming.charsPerStep == 6)
        #expect(mediumQueueTiming.charsPerStep == 8)
        #expect(highQueueTiming.charsPerStep == 10)

        #expect(approximatelyEqual(lowQueueTiming.baseDuration, Self.balancedLowBaseDuration))
        #expect(approximatelyEqual(mediumQueueTiming.baseDuration, Self.balancedMediumBaseDuration))
        #expect(approximatelyEqual(highQueueTiming.baseDuration, Self.balancedHighBaseDuration))

        #expect(approximatelyEqual(lowQueueTiming.elementGapDuration, 0.030))
        #expect(approximatelyEqual(mediumQueueTiming.elementGapDuration, 0.020))
        #expect(approximatelyEqual(highQueueTiming.elementGapDuration, 0.012))

        #expect(approximatelyEqual(lowQueueTiming.commaPause, 0.015))
        #expect(approximatelyEqual(lowQueueTiming.sentencePause, 0.045))
    }

    @Test("Fade configuration does not affect resolved pacing")
    func fadeConfigurationDoesNotAffectResolvedTiming() {
        let baselineConfiguration = TypewriterConfiguration.balanced
        var fadingConfiguration = TypewriterConfiguration.balanced
        fadingConfiguration.textRevealInitialAlpha = 0.05
        fadingConfiguration.textRevealFadeDuration = 0.30

        let baselineTiming = RevealTiming(
            pendingTaskCount: 6,
            typewriterConfiguration: baselineConfiguration,
            performanceProfile: .balanced
        )
        let fadingTiming = RevealTiming(
            pendingTaskCount: 6,
            typewriterConfiguration: fadingConfiguration,
            performanceProfile: .balanced
        )

        #expect(baselineTiming == fadingTiming)
    }

    @Test("Explicit timing remains deterministic")
    func explicitTimingRemainsDeterministic() {
        let resolvedTiming = RevealTiming(
            charsPerStep: 11,
            baseDuration: 0.004,
            elementGapDuration: 0.001,
            commaPause: 0.015,
            sentencePause: 0.045,
            jitterMax: 0.005
        )

        #expect(resolvedTiming.charsPerStep == 11)
        #expect(approximatelyEqual(resolvedTiming.baseDuration, 0.004))
        #expect(approximatelyEqual(resolvedTiming.elementGapDuration, 0.001))
        #expect(approximatelyEqual(resolvedTiming.commaPause, 0.015))
        #expect(approximatelyEqual(resolvedTiming.sentencePause, 0.045))
    }

    @Test("Buffered timing preset matches expected values")
    func bufferedTimingPresetMatchesExpectedValues() {
        let bufferedTiming = RevealTiming.buffered

        #expect(bufferedTiming.charsPerStep == 4)
        #expect(approximatelyEqual(bufferedTiming.baseDuration, 0.014))
        #expect(approximatelyEqual(bufferedTiming.elementGapDuration, 0.04))
        #expect(approximatelyEqual(bufferedTiming.commaPause, 0.03))
        #expect(approximatelyEqual(bufferedTiming.sentencePause, 0.08))
        #expect(approximatelyEqual(bufferedTiming.jitterMax, 0.005))
    }

    @Test("Minimum text animation window slows down short reveals deterministically")
    func minimumTextAnimationWindowSlowsShortReveals() {
        let baseTiming = RevealTiming(
            charsPerStep: 6,
            baseDuration: 0.012,
            elementGapDuration: 0.04,
            commaPause: 0.03,
            sentencePause: 0.08,
            jitterMax: 0.005
        )

        let regularTextTiming = baseTiming.next(totalCharacters: 120, minimumTextAnimationWindow: 0.24)
        let shortTextTiming = baseTiming.next(totalCharacters: 20, minimumTextAnimationWindow: 0.24)
        let tinyTextTiming = baseTiming.next(totalCharacters: 6, minimumTextAnimationWindow: 0.24)

        #expect(regularTextTiming.charsPerStep == 6)
        #expect(shortTextTiming.charsPerStep == 1)
        #expect(tinyTextTiming.charsPerStep == 1)
        #expect(approximatelyEqual(shortTextTiming.baseDuration, 0.012))
        #expect(approximatelyEqual(tinyTextTiming.baseDuration, 0.04))
        #expect(shortTextTiming.jitterMax == baseTiming.jitterMax)
        #expect(tinyTextTiming.jitterMax > baseTiming.jitterMax)
    }

    @Test("Performance profile scales base timings")
    func performanceProfileScalesBaseTimings() {
        let balancedTiming = RevealTiming(
            pendingTaskCount: 1,
            typewriterConfiguration: .balanced,
            performanceProfile: .balanced
        )
        let snappyTiming = RevealTiming(
            pendingTaskCount: 1,
            typewriterConfiguration: .balanced,
            performanceProfile: .snappy
        )
        let longFormTiming = RevealTiming(
            pendingTaskCount: 1,
            typewriterConfiguration: .balanced,
            performanceProfile: .longForm
        )

        #expect(snappyTiming.baseDuration < balancedTiming.baseDuration)
        #expect(longFormTiming.baseDuration > balancedTiming.baseDuration)
        #expect(snappyTiming.elementGapDuration < balancedTiming.elementGapDuration)
        #expect(longFormTiming.elementGapDuration > balancedTiming.elementGapDuration)
    }
}

private extension RevealSequencerProfileTests {
    func approximatelyEqual(
        _ leftValue: TimeInterval,
        _ rightValue: TimeInterval,
        tolerance: TimeInterval = Self.timingTolerance
    ) -> Bool {
        abs(leftValue - rightValue) <= tolerance
    }
}
