import Foundation
import QuillCore

extension StreamCoordinator {
    func applyStreamingSnapshot(_ snapshot: StreamingSnapshot) {
        let outcome = renderer.render(
            blocks: snapshot.blocks,
            frozenCount: snapshot.frozenCount
        )
        renderer.updateSelectionGate(isStreaming: true)

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
        // Reset drops any text still buffered in ModuleStreamGate instead of flushing it.
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
        let reduceID = QuillSignpost.reduce.makeSignpostID()
        let reduceSignpost = QuillSignpost.reduce.beginInterval("reduce", id: reduceID)
        BlockReducer.apply(event, to: &state)
        QuillSignpost.reduce.endInterval("reduce", reduceSignpost)

        let snapshot = StreamingSnapshot(
            blocks: state.blocks,
            frozenCount: state.frozenCount
        )

        let snapshotID = QuillSignpost.render.makeSignpostID()
        let snapshotSignpost = QuillSignpost.render.beginInterval("applySnapshot", id: snapshotID)
        applyStreamingSnapshot(snapshot)
        QuillSignpost.render.endInterval("applySnapshot", snapshotSignpost)
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
        accumulatedMarkdown: String?,
        configuration: QuillConfiguration,
        needsRestart: Bool
    ) {
        guard needsRestart else { return }
        startStream(
            bootstrap: accumulatedMarkdown,
            configuration: configuration
        )
    }

    func syncConfiguration(_ configuration: RenderConfiguration) {
        renderConfiguration = configuration
        bufferedStreamCommitScheduler.applyConfiguration(configuration)
        renderer.applyTailRevealPolicy(configuration.tailReveal)
    }
}
