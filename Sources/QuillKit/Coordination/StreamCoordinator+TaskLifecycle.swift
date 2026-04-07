import Foundation
import QuillCore

extension StreamCoordinator {
    func applyStreamingSnapshot(_ snapshot: StreamingSnapshot) {
        let outcome = renderer.render(
            blocks: snapshot.blocks,
            frozenCount: snapshot.frozenCount
        )

        guard outcome.invalidatedHeight else { return }
        invalidateHeight(for: .rendererSnapshotApplied)
    }

    func cancelActiveWork() {
        lastTailRevealHeightInvalidation = 0
        renderer.cancelStreaming()
        bufferedVisualFeeder.cancel()
        streamTask?.cancel()
        streamTask = nil
        finishTask?.cancel()
        finishTask = nil
        bufferedStreamCommitScheduler.reset()
        controller = nil
        streamGeneration += 1
    }

    func cancelAllTasks() {
        cancelActiveWork()
    }

    func handleParserEvent(
        _ event: ParserEvent,
        state: inout BlockReducer.ReducerState
    ) {
        BlockReducer.apply(event, to: &state)

        let snapshot = StreamingSnapshot(
            blocks: state.blocks,
            frozenCount: state.frozenCount
        )
        applyStreamingSnapshot(snapshot)
    }

    func startStream(
        bootstrap: String? = nil,
        configuration: QuillConfiguration
    ) {
        cancelStreaming()
        apply(configuration: configuration)

        let streamController = makeStreamController()
        controller = streamController

        let generation = streamGeneration
        streamTask = Task { [weak self] in
            var state = BlockReducer.ReducerState()
            let events = await streamController.events()

            if let bootstrap, !bootstrap.isEmpty {
                await streamController.append(bootstrap)
            }

            for await event in events {
                guard !Task.isCancelled, let self, self.streamGeneration == generation else { break }

                self.handleParserEvent(
                    event,
                    state: &state
                )
            }
        }
    }

    func startStreamIfNeeded(
        currentMarkdown: String?,
        configuration: QuillConfiguration,
        needsRestart: Bool
    ) {
        guard needsRestart else { return }
        startStream(
            bootstrap: currentMarkdown,
            configuration: configuration
        )
    }

    func syncConfiguration(_ configuration: RenderConfiguration) {
        renderConfiguration = configuration
        bufferedStreamCommitScheduler.applyConfiguration(configuration)
        renderer.applyTailRevealPolicy(configuration.tailReveal)
    }
}
