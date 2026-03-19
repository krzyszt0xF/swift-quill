import Foundation

package struct RenderConfiguration: Equatable, Sendable {
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
        tail: TailConfiguration = .init(aggressiveness: .balanced),
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

extension RenderConfiguration {
    init(preset: QuillStreamingPreset) {
        switch preset {
        case .balanced:
            self = RenderConfiguration(
                streamingMode: .bufferedModules,
                performanceProfile: .balanced,
                typewriter: .balanced,
                layout: .default,
                tail: .init(aggressiveness: .balanced),
                bufferedStream: .default
            )
        case let .custom(speedMultiplier, tailAggressiveness, bufferingDelay):
            let clampedSpeed = min(max(0.75, speedMultiplier), 1.5)
            self = RenderConfiguration(
                streamingMode: .bufferedModules,
                performanceProfile: .balanced,
                typewriter: .balanced.scaled(by: clampedSpeed),
                layout: .default,
                tail: .init(aggressiveness: tailAggressiveness),
                bufferedStream: .init(
                    minModuleLength: 50,
                    maxBufferingDelay: max(0.1, bufferingDelay)))
        case .longForm:
            self = RenderConfiguration(
                streamingMode: .bufferedModules,
                performanceProfile: .longForm,
                typewriter: .longForm,
                layout: .longForm,
                tail: .init(aggressiveness: .conservative),
                bufferedStream: .default
            )
        case .snappy:
            self = RenderConfiguration(
                streamingMode: .bufferedModules,
                performanceProfile: .snappy,
                typewriter: .snappy,
                layout: .snappy,
                tail: .init(aggressiveness: .aggressive),
                bufferedStream: .default
            )
        }
    }
}
