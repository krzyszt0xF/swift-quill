import Foundation

package struct RenderConfiguration: Equatable, Sendable {
    var bufferedStream: BufferedStreamConfiguration
    var layout: LayoutConfiguration
    var performanceProfile: PerformanceProfile
    var streamingMode: StreamingMode
    var tailReveal: TailRevealPolicy

    init(
        streamingMode: StreamingMode,
        performanceProfile: PerformanceProfile,
        tailReveal: TailRevealPolicy,
        layout: LayoutConfiguration,
        bufferedStream: BufferedStreamConfiguration
    ) {
        self.bufferedStream = bufferedStream
        self.layout = layout
        self.performanceProfile = performanceProfile
        self.streamingMode = streamingMode
        self.tailReveal = tailReveal
    }
}

extension RenderConfiguration {
    init(preset: QuillStreamingPreset) {
        switch preset {
        case .balanced:
            self = RenderConfiguration(
                streamingMode: .smoothedTail,
                performanceProfile: .balanced,
                tailReveal: .balanced,
                layout: .default,
                bufferedStream: .default
            )
        case let .bufferedCustom(speedMultiplier, bufferingDelay, minModuleLength):
            let clampedSpeed = min(max(0.25, speedMultiplier), 1.5)
            self = RenderConfiguration(
                streamingMode: .smoothedTail,
                performanceProfile: .balanced,
                tailReveal: .balanced.scaled(by: clampedSpeed),
                layout: .default,
                bufferedStream: .init(
                    minModuleLength: max(1, minModuleLength),
                    maxBufferingDelay: max(0.1, bufferingDelay)
                )
            )
        case let .custom(speedMultiplier, bufferingDelay):
            let clampedSpeed = min(max(0.75, speedMultiplier), 1.5)
            self = RenderConfiguration(
                streamingMode: .smoothedTail,
                performanceProfile: .balanced,
                tailReveal: .balanced.scaled(by: clampedSpeed),
                layout: .default,
                bufferedStream: .init(
                    minModuleLength: 50,
                    maxBufferingDelay: max(0.1, bufferingDelay)))
        case .longForm:
            self = RenderConfiguration(
                streamingMode: .smoothedTail,
                performanceProfile: .longForm,
                tailReveal: .longForm,
                layout: .longForm,
                bufferedStream: .default
            )
        case .snappy:
            self = RenderConfiguration(
                streamingMode: .smoothedTail,
                performanceProfile: .snappy,
                tailReveal: .snappy,
                layout: .snappy,
                bufferedStream: .default
            )
        }
    }

    static let `default` = Self(
        streamingMode: .smoothedTail,
        performanceProfile: .balanced,
        tailReveal: .balanced,
        layout: .default,
        bufferedStream: .default)
}
