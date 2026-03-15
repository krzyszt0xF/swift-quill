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
        let sequencer = RevealSequencer()
        sequencer.applyConfiguration(typewriter: .balanced, performanceProfile: .balanced)

        let lowQueueTiming = sequencer.resolvedTiming(forPendingTaskCount: 1)
        let mediumQueueTiming = sequencer.resolvedTiming(forPendingTaskCount: 4)
        let highQueueTiming = sequencer.resolvedTiming(forPendingTaskCount: 10)

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
        let sequencer = RevealSequencer()
        let baselineConfiguration = TypewriterConfiguration.balanced
        var fadingConfiguration = TypewriterConfiguration.balanced
        fadingConfiguration.textRevealInitialAlpha = 0.05
        fadingConfiguration.textRevealFadeDuration = 0.30

        sequencer.applyConfiguration(typewriter: baselineConfiguration, performanceProfile: .balanced)
        let baselineTiming = sequencer.resolvedTiming(forPendingTaskCount: 6)

        sequencer.applyConfiguration(typewriter: fadingConfiguration, performanceProfile: .balanced)
        let fadingTiming = sequencer.resolvedTiming(forPendingTaskCount: 6)

        #expect(baselineTiming == fadingTiming)
    }

    @Test("Manual fixed timing remains deterministic")
    func fixedTimingRemainsDeterministic() {
        let sequencer = RevealSequencer()
        sequencer.applyConfiguration(typewriter: .balanced, performanceProfile: .balanced)
        sequencer.setFixedTiming(
            .init(
                charsPerStep: 11,
                baseDuration: 0.004,
                elementGapDuration: 0.001,
                commaPause: 0.015,
                sentencePause: 0.045,
                jitterMax: 0.005
            )
        )

        let resolvedTiming = sequencer.resolvedTiming(forPendingTaskCount: 30)

        #expect(resolvedTiming.charsPerStep == 11)
        #expect(approximatelyEqual(resolvedTiming.baseDuration, 0.004))
        #expect(approximatelyEqual(resolvedTiming.elementGapDuration, 0.001))
        #expect(approximatelyEqual(resolvedTiming.commaPause, 0.015))
        #expect(approximatelyEqual(resolvedTiming.sentencePause, 0.045))
    }

    @Test("Fixed timing override ignores queue depth")
    func fixedTimingIgnoresQueueDepth() {
        let sequencer = RevealSequencer()
        sequencer.applyConfiguration(typewriter: .balanced, performanceProfile: .balanced)
        sequencer.setFixedTiming(
            .init(
                charsPerStep: 6,
                baseDuration: 0.012,
                elementGapDuration: 0.04,
                commaPause: 0.03,
                sentencePause: 0.08,
                jitterMax: 0.005
            )
        )

        let lowQueueTiming = sequencer.resolvedTiming(forPendingTaskCount: 1)
        let highQueueTiming = sequencer.resolvedTiming(forPendingTaskCount: 24)

        #expect(lowQueueTiming == highQueueTiming)
        #expect(approximatelyEqual(lowQueueTiming.commaPause, 0.03))
        #expect(approximatelyEqual(lowQueueTiming.sentencePause, 0.08))
        #expect(approximatelyEqual(lowQueueTiming.jitterMax, 0.005))
        #expect(approximatelyEqual(lowQueueTiming.baseDuration, 0.012))
        #expect(approximatelyEqual(lowQueueTiming.elementGapDuration, 0.04))
    }

    @Test("Minimum text animation window slows down short reveals deterministically")
    func minimumTextAnimationWindowSlowsShortReveals() {
        let sequencer = RevealSequencer()
        sequencer.setMinimumTextAnimationWindow(0.24)

        let baseTiming = RevealSequencer.ResolvedTiming(
            charsPerStep: 6,
            baseDuration: 0.012,
            elementGapDuration: 0.04,
            commaPause: 0.03,
            sentencePause: 0.08,
            jitterMax: 0.005
        )

        let regularTextTiming = sequencer.resolveTextTiming(baseTiming, totalCharacters: 120)
        let shortTextTiming = sequencer.resolveTextTiming(baseTiming, totalCharacters: 20)
        let tinyTextTiming = sequencer.resolveTextTiming(baseTiming, totalCharacters: 6)

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
        let sequencer = RevealSequencer()
        sequencer.applyConfiguration(typewriter: .balanced, performanceProfile: .balanced)
        let balancedTiming = sequencer.resolvedTiming(forPendingTaskCount: 1)

        sequencer.applyConfiguration(typewriter: .balanced, performanceProfile: .snappy)
        let snappyTiming = sequencer.resolvedTiming(forPendingTaskCount: 1)

        sequencer.applyConfiguration(typewriter: .balanced, performanceProfile: .longForm)
        let longFormTiming = sequencer.resolvedTiming(forPendingTaskCount: 1)

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
