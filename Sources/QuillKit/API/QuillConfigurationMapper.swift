import CoreGraphics
import Foundation

enum QuillConfigurationMapper {
    static func resolve(_ preset: QuillStreamingPreset) -> QuillRenderConfiguration {
        switch preset {
        case .balanced:
            return balancedConfiguration()
        case .custom(let speedMultiplier, let tailAggressiveness, let bufferingDelay):
            return customConfiguration(
                speedMultiplier: speedMultiplier,
                tailAggressiveness: tailAggressiveness,
                bufferingDelay: bufferingDelay
            )
        case .longForm:
            return longFormConfiguration()
        case .snappy:
            return snappyConfiguration()
        }
    }
}

// MARK: - Presets

private extension QuillConfigurationMapper {
    static func balancedConfiguration() -> QuillRenderConfiguration {
        QuillRenderConfiguration(
            streamingMode: .bufferedModules,
            performanceProfile: .balanced,
            typewriter: .balanced,
            layout: .default,
            tail: .default,
            bufferedStream: .default
        )
    }

    static func longFormConfiguration() -> QuillRenderConfiguration {
        QuillRenderConfiguration(
            streamingMode: .bufferedModules,
            performanceProfile: .longForm,
            typewriter: .longForm,
            layout: .longForm,
            tail: tailConfiguration(for: .conservative),
            bufferedStream: .default
        )
    }

    static func snappyConfiguration() -> QuillRenderConfiguration {
        QuillRenderConfiguration(
            streamingMode: .bufferedModules,
            performanceProfile: .snappy,
            typewriter: .snappy,
            layout: .snappy,
            tail: tailConfiguration(for: .aggressive),
            bufferedStream: .default
        )
    }

    static func customConfiguration(
        speedMultiplier: Double,
        tailAggressiveness: TailAggressiveness,
        bufferingDelay: TimeInterval
    ) -> QuillRenderConfiguration {
        let clampedSpeed = min(max(0.75, speedMultiplier), 1.5)

        return QuillRenderConfiguration(
            streamingMode: .bufferedModules,
            performanceProfile: .balanced,
            typewriter: scaledTypewriter(.balanced, by: clampedSpeed),
            layout: .default,
            tail: tailConfiguration(for: tailAggressiveness),
            bufferedStream: .init(minModuleLength: 50, maxBufferingDelay: max(0.1, bufferingDelay))
        )
    }
}

// MARK: - Tail

private extension QuillConfigurationMapper {
    static func tailConfiguration(for aggressiveness: TailAggressiveness) -> TailConfiguration {
        switch aggressiveness {
        case .aggressive:
            return TailConfiguration(
                flowTailBaseDuration: 0.024,
                flowTailStartBufferCharacters: 56,
                flowTailMaxStartDelay: 0.7,
                flowTailIdleTimeout: 1.0,
                flowTailUpdateCoalescingInterval: 0.04
            )
        case .balanced:
            return .default
        case .conservative:
            return TailConfiguration(
                flowTailBaseDuration: 0.038,
                flowTailStartBufferCharacters: 96,
                flowTailMaxStartDelay: 1.4,
                flowTailIdleTimeout: 1.8,
                flowTailUpdateCoalescingInterval: 0.06
            )
        }
    }
}

// MARK: - Typewriter Scaling

private extension QuillConfigurationMapper {
    static func scaledTypewriter(_ base: TypewriterConfiguration, by speed: Double) -> TypewriterConfiguration {
        TypewriterConfiguration(
            lowQueue: scaledQueueTiming(base.lowQueue, by: speed),
            mediumQueue: scaledQueueTiming(base.mediumQueue, by: speed),
            highQueue: scaledQueueTiming(base.highQueue, by: speed),
            mediumQueueLowerBound: base.mediumQueueLowerBound,
            highQueueLowerBound: base.highQueueLowerBound,
            commaPause: base.commaPause / speed,
            sentencePause: base.sentencePause / speed,
            jitterMax: base.jitterMax,
            textRevealInitialAlpha: base.textRevealInitialAlpha,
            textRevealFadeDuration: base.textRevealFadeDuration
        )
    }

    static func scaledQueueTiming(
        _ timing: TypewriterConfiguration.QueueTiming,
        by speed: Double
    ) -> TypewriterConfiguration.QueueTiming {
        TypewriterConfiguration.QueueTiming(
            charsPerStep: max(1, Int((Double(timing.charsPerStep) * speed).rounded())),
            baseDuration: timing.baseDuration / speed,
            elementGapDuration: timing.elementGapDuration / speed
        )
    }
}
