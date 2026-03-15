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
func makeHybridTailQuillView() -> QuillView {
    makeQuillView(mode: .hybridTail)
}

@MainActor
func makeQuillView(
    mode: StreamingMode = .stableBlocks,
    bufferedStreamConfiguration: BufferedStreamConfiguration? = nil
) -> QuillView {
    var configuration = QuillRenderConfiguration(
        streamingMode: mode,
        performanceProfile: .balanced,
        typewriter: .balanced,
        layout: .init(heightMeasurementCoalescingInterval: 0.005),
        tail: .default
    )

    if mode == .bufferedModules {
        configuration.bufferedStream = bufferedStreamConfiguration ?? BufferedStreamConfiguration(
            minModuleLength: 1,
            maxBufferingDelay: 0.1
        )
    }

    let view = QuillView(
        frame: CGRect(x: 0, y: 0, width: 320, height: 0),
        internalConfiguration: configuration
    )
    view.layoutIfNeeded()
    return view
}

@MainActor
func makeStableBlocksQuillView() -> QuillView {
    makeQuillView(mode: .stableBlocks)
}
