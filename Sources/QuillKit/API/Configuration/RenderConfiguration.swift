import Foundation

package struct RenderConfiguration: Equatable, Sendable {
    var streamingMode: StreamingMode
    var performanceProfile: PerformanceProfile
    var typewriter: TypewriterConfiguration
    var layout: LayoutConfiguration
    var bufferedStream: BufferedStreamConfiguration
    
    init(
        streamingMode: StreamingMode = .bufferedModules,
        performanceProfile: PerformanceProfile = .balanced,
        typewriter: TypewriterConfiguration = .balanced,
        layout: LayoutConfiguration = .default,
        bufferedStream: BufferedStreamConfiguration = .default
    ) {
        self.streamingMode = streamingMode
        self.performanceProfile = performanceProfile
        self.typewriter = typewriter
        self.layout = layout
        self.bufferedStream = bufferedStream
    }
}

extension RenderConfiguration {
    init(preset: QuillStreamingPreset) {
        switch preset {
        case .balanced:
            self = RenderConfiguration(
                streamingMode: .bufferedModules,
                performanceProfile: .balanced,
                typewriter: .balanced,
                layout: .default,
                bufferedStream: .default
            )
        case let .custom(speedMultiplier, bufferingDelay):
            let clampedSpeed = min(max(0.75, speedMultiplier), 1.5)
            self = RenderConfiguration(
                streamingMode: .bufferedModules,
                performanceProfile: .balanced,
                typewriter: .balanced.scaled(by: clampedSpeed),
                layout: .default,
                bufferedStream: .init(
                    minModuleLength: 50,
                    maxBufferingDelay: max(0.1, bufferingDelay)))
        case .longForm:
            self = RenderConfiguration(
                streamingMode: .bufferedModules,
                performanceProfile: .longForm,
                typewriter: .longForm,
                layout: .longForm,
                bufferedStream: .default
            )
        case .snappy:
            self = RenderConfiguration(
                streamingMode: .bufferedModules,
                performanceProfile: .snappy,
                typewriter: .snappy,
                layout: .snappy,
                bufferedStream: .default
            )
        }
    }
}
