@testable import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("Internal Dependencies")
struct InternalDependencyTests {
    @Test("FrozenBlockRenderer uses injected ID generator")
    func frozenBlockRendererUsesInjectedIDGenerator() {
        let ids = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        ]
        let idSource = IDSource(ids: ids)
        var renderer = FrozenBlockRenderer(
            generateID: { idSource.next() },
            nodeViewFactory: RenderNodeViewFactory { _ in UIView() }
        )
        let containerView = BlockContainerView()
        let nodes: [RenderNode] = [
            .flow(.init(blocks: [.paragraph(content: [.text("first")])])),
            .flow(.init(blocks: [.paragraph(content: [.text("second")])])),
        ]

        renderer.applyContainerUpdate(
            nodes: nodes,
            frozenNodeCount: 2,
            containerView: containerView,
            linkTapHandler: nil
        )

        #expect(renderer.stateRegistry.map(\.id) == ids)
    }

    @Test("StreamCoordinator uses injected stream controller factory")
    func streamCoordinatorUsesInjectedStreamControllerFactory() {
        let streamControllerFactory = Counter()
        let coordinator = StreamCoordinator(
            renderer: makeStreamingBlockRenderer(),
            sequencer: makeRevealSequencer(),
            moduleStreamGate: .init(),
            now: { 0 },
            sleep: { _ in },
            streamController: {
                streamControllerFactory.increment()
                return MarkdownStreamController()
            }
        )
        let configuration = RenderConfiguration(
            streamingMode: .stableBlocks,
            performanceProfile: .balanced,
            typewriter: .balanced,
            layout: .default,
            tail: .default
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
                renderer: makeStreamingBlockRenderer(),
                sequencer: makeRevealSequencer(),
                moduleStreamGate: .init(),
                now: { 0 },
                sleep: { _ in },
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
            streamingMode: .stableBlocks,
            performanceProfile: .balanced,
            typewriter: .balanced,
            layout: .default,
            tail: .default
        )
        let dependencies = QuillView.Dependencies(
            heightCoordinator: HeightCoordinator(),
            markdownParser: .live,
            streamCoordinator: StreamCoordinator(
                renderer: makeStreamingBlockRenderer(),
                sequencer: makeRevealSequencer(),
                moduleStreamGate: .init(),
                now: { 0 },
                sleep: { _ in },
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

private final class IDSource {
    private let ids: [UUID]
    private var index = 0

    init(ids: [UUID]) {
        self.ids = ids
    }

    func next() -> UUID {
        defer { index += 1 }
        return ids[index]
    }
}
