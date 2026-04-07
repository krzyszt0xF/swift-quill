@testable import QuillKit
import CoreGraphics
import Foundation
import QuillCore

@MainActor
func makeBufferedModulesQuillView(
    minModuleLength: Int,
    maxBufferingDelay: TimeInterval,
    schedulerTimeController: TestTimeController? = nil
) -> QuillView {
    let bufferedStreamConfiguration = BufferedStreamConfiguration(
        minModuleLength: minModuleLength,
        maxBufferingDelay: maxBufferingDelay
    )

    return makeQuillView(
        mode: .bufferedModules,
        bufferedStreamConfiguration: bufferedStreamConfiguration,
        schedulerTimeController: schedulerTimeController
    )
}

@MainActor
func makeQuillView(
    mode: StreamingMode = .smoothedTail,
    bufferedStreamConfiguration: BufferedStreamConfiguration? = nil,
    schedulerTimeController: TestTimeController? = nil
) -> QuillView {
    var renderConfiguration = RenderConfiguration(
        streamingMode: mode,
        performanceProfile: .balanced,
        tailReveal: .balanced,
        layout: .init(heightMeasurementCoalescingInterval: 0.005),
        bufferedStream: .default
    )

    if mode == .bufferedModules {
        renderConfiguration.bufferedStream = bufferedStreamConfiguration ?? BufferedStreamConfiguration(
            minModuleLength: 1,
            maxBufferingDelay: 0.1
        )
    }

    let configuration = QuillConfiguration(
        streaming: .init(mode: mode, preset: .balanced),
        renderConfiguration: renderConfiguration
    )

    let dependencies = if let schedulerTimeController {
        makeQuillViewDependencies(
            renderConfiguration: renderConfiguration,
            schedulerTimeController: schedulerTimeController
        )
    } else {
        QuillView.Dependencies.live
    }

    let view = QuillView(
        frame: CGRect(x: 0, y: 0, width: 320, height: 0),
        configuration: configuration,
        dependencies: dependencies
    )
    view.layoutIfNeeded()
    return view
}

@MainActor
func makeSmoothedTailQuillView() -> QuillView {
    makeQuillView(mode: .smoothedTail)
}

@MainActor
private func makeQuillViewDependencies(
    renderConfiguration: RenderConfiguration,
    schedulerTimeController: TestTimeController
) -> QuillView.Dependencies {
    let renderer = makeDocumentRenderer()
    let scheduler = BufferedStreamCommitScheduler(
        moduleStreamGate: .init(),
        now: { schedulerTimeController.now() },
        sleep: { duration in
            await schedulerTimeController.sleep(for: duration)
        }
    )
    let streamCoordinator = StreamCoordinator(
        renderer: renderer,
        renderConfiguration: renderConfiguration,
        bufferedStreamCommitScheduler: scheduler,
        bufferedVisualFeeder: .init(sleep: { duration in
            await schedulerTimeController.sleep(for: duration)
        }),
        streamController: MarkdownStreamController.init
    )

    return QuillView.Dependencies(
        heightCoordinator: HeightCoordinator(),
        markdownParser: .live,
        streamCoordinator: streamCoordinator
    )
}
