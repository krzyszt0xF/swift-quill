@testable import QuillKit
import CoreGraphics
import Foundation

@MainActor
func makeBufferedModulesQuillView(
    minModuleLength: Int,
    maxBufferingDelay: TimeInterval
) -> QuillView {
    let bufferedStreamConfiguration = BufferedStreamConfiguration(
        minModuleLength: minModuleLength,
        maxBufferingDelay: maxBufferingDelay
    )

    return makeQuillView(
        mode: .bufferedModules,
        bufferedStreamConfiguration: bufferedStreamConfiguration
    )
}

@MainActor
func makeQuillView(
    mode: StreamingMode = .smoothedTail,
    bufferedStreamConfiguration: BufferedStreamConfiguration? = nil
) -> QuillView {
    var configuration = RenderConfiguration(
        streamingMode: mode,
        performanceProfile: .balanced,
        tailReveal: .balanced,
        layout: .init(heightMeasurementCoalescingInterval: 0.005),
        bufferedStream: .default
    )

    if mode == .bufferedModules {
        configuration.bufferedStream = bufferedStreamConfiguration ?? BufferedStreamConfiguration(
            minModuleLength: 1,
            maxBufferingDelay: 0.1
        )
    }

    let view = QuillView(
        frame: CGRect(x: 0, y: 0, width: 320, height: 0),
        configuration: configuration,
        dependencies: .live
    )
    view.layoutIfNeeded()
    return view
}

@MainActor
func makeSmoothedTailQuillView() -> QuillView {
    makeQuillView(mode: .smoothedTail)
}
