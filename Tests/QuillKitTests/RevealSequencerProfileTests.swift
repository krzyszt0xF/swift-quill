@testable import QuillKit
import Foundation
import Testing

@MainActor
@Suite("Reveal Sequencer Profiles")
struct RevealSequencerProfileTests {
    @Test("Balanced profile resolves expected queue tiers")
    func balancedQueueTiers() {
        let sequencer = RevealSequencer()
        sequencer.applyConfiguration(typewriter: .balanced, performanceProfile: .balanced)

        let low = sequencer.resolvedTiming(forPendingTaskCount: 1)
        let medium = sequencer.resolvedTiming(forPendingTaskCount: 4)
        let high = sequencer.resolvedTiming(forPendingTaskCount: 10)

        #expect(low.charsPerStep == 6)
        #expect(medium.charsPerStep == 8)
        #expect(high.charsPerStep == 10)

        #expect(approximatelyEqual(low.baseDuration, 0.012))
        #expect(approximatelyEqual(medium.baseDuration, 0.010))
        #expect(approximatelyEqual(high.baseDuration, 0.008))

        #expect(approximatelyEqual(low.elementGapDuration, 0.030))
        #expect(approximatelyEqual(medium.elementGapDuration, 0.020))
        #expect(approximatelyEqual(high.elementGapDuration, 0.012))

        #expect(approximatelyEqual(low.commaPause, 0.015))
        #expect(approximatelyEqual(low.sentencePause, 0.045))
    }

    @Test("Performance profile scales base timings")
    func profileScaling() {
        let sequencer = RevealSequencer()
        sequencer.applyConfiguration(typewriter: .balanced, performanceProfile: .balanced)
        let balanced = sequencer.resolvedTiming(forPendingTaskCount: 1)

        sequencer.applyConfiguration(typewriter: .balanced, performanceProfile: .snappy)
        let snappy = sequencer.resolvedTiming(forPendingTaskCount: 1)

        sequencer.applyConfiguration(typewriter: .balanced, performanceProfile: .longForm)
        let longForm = sequencer.resolvedTiming(forPendingTaskCount: 1)

        #expect(snappy.baseDuration < balanced.baseDuration)
        #expect(longForm.baseDuration > balanced.baseDuration)
        #expect(snappy.elementGapDuration < balanced.elementGapDuration)
        #expect(longForm.elementGapDuration > balanced.elementGapDuration)
    }

    @Test("Manual speed override remains deterministic")
    func speedOverride() {
        let sequencer = RevealSequencer()
        sequencer.applyConfiguration(typewriter: .balanced, performanceProfile: .balanced)
        sequencer.updateSpeed(charsPerStep: 11, baseDuration: 0.004, elementGapDuration: 0.001)

        let resolved = sequencer.resolvedTiming(forPendingTaskCount: 30)

        #expect(resolved.charsPerStep == 11)
        #expect(approximatelyEqual(resolved.baseDuration, 0.004))
        #expect(approximatelyEqual(resolved.elementGapDuration, 0.001))
        #expect(approximatelyEqual(resolved.commaPause, 0.015))
        #expect(approximatelyEqual(resolved.sentencePause, 0.045))
    }
}

private extension RevealSequencerProfileTests {
    func approximatelyEqual(_ lhs: TimeInterval, _ rhs: TimeInterval, tolerance: TimeInterval = 0.0001) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}
