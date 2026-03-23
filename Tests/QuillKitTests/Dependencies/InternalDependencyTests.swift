@testable import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("Internal Dependencies")
struct InternalDependencyTests {
    @Test("StreamCoordinator uses injected stream controller factory")
    func streamCoordinatorUsesInjectedStreamControllerFactory() {
        let streamControllerFactory = Counter()
        let coordinator = StreamCoordinator(
            renderer: makeDocumentRenderer(),
            renderConfiguration: .default,
            bufferedStreamCommitScheduler: BufferedStreamCommitScheduler(
                moduleStreamGate: .init(),
                now: { 0 },
                sleep: { _ in }
            ),
            bufferedVisualFeeder: .live,
            streamController: {
                streamControllerFactory.increment()
                return MarkdownStreamController()
            }
        )
        let configuration = RenderConfiguration(
            streamingMode: .smoothedTail,
            performanceProfile: .balanced,
            tailReveal: .balanced,
            layout: .default,
            bufferedStream: .default
        )

        coordinator.append(
            "hello",
            currentMarkdown: nil,
            configuration: configuration,
            needsRestart: true
        )

        #expect(streamControllerFactory.value == 1)
    }

    @Test("QuillView dependencies use injected markdown parser")
    func quillViewDependenciesUseInjectedMarkdownParser() {
        let parserCounter = Counter()
        let dependencies = QuillView.Dependencies(
            heightCoordinator: HeightCoordinator(),
            markdownParser: MarkdownParser { _ in
                parserCounter.increment()
                return []
            },
            streamCoordinator: StreamCoordinator(
                renderer: makeDocumentRenderer(),
                renderConfiguration: .default,
                bufferedStreamCommitScheduler: BufferedStreamCommitScheduler(
                    moduleStreamGate: .init(),
                    now: { 0 },
                    sleep: { _ in }
                ),
                bufferedVisualFeeder: .live,
                streamController: MarkdownStreamController.init
            )
        )
        _ = dependencies.markdownParser.parse("# test")

        #expect(parserCounter.value == 1)
    }

    @Test("QuillView dependencies use injected stream coordinator")
    func quillViewDependenciesUseInjectedStreamCoordinator() {
        let streamControllerFactory = Counter()
        let configuration = RenderConfiguration(
            streamingMode: .smoothedTail,
            performanceProfile: .balanced,
            tailReveal: .balanced,
            layout: .default,
            bufferedStream: .default
        )
        let dependencies = QuillView.Dependencies(
            heightCoordinator: HeightCoordinator(),
            markdownParser: .live,
            streamCoordinator: StreamCoordinator(
                renderer: makeDocumentRenderer(),
                renderConfiguration: .default,
                bufferedStreamCommitScheduler: BufferedStreamCommitScheduler(
                    moduleStreamGate: .init(),
                    now: { 0 },
                    sleep: { _ in }
                ),
                bufferedVisualFeeder: .live,
                streamController: {
                    streamControllerFactory.increment()
                    return MarkdownStreamController()
                }
            )
        )
        dependencies.streamCoordinator.append(
            "hello",
            currentMarkdown: nil,
            configuration: configuration,
            needsRestart: true
        )

        #expect(streamControllerFactory.value == 1)
    }
}

private final class Counter: @unchecked Sendable {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
