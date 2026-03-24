import QuillCore
import QuillSharedTestSupport

package func collectEvents(
    from controller: MarkdownStreamController,
    feeding chunks: [String]) async -> [ParserEvent] {
        let eventStream = await controller.events()
        
        Task {
            for chunk in chunks {
                await controller.append(chunk)
            }
            await controller.finish()
        }
        
        var collectedEvents: [ParserEvent] = []
        for await event in eventStream {
            collectedEvents.append(event)
        }
        
        return collectedEvents
}

package func reduce(_ events: [ParserEvent]) -> [Block] {
    var reducerState = BlockReducer.ReducerState()
    for event in events {
        BlockReducer.apply(event, to: &reducerState)
    }
    return normalizedBlocks(reducerState.blocks)
}

package func streamAndReduce(_ markdown: String, chunkSizes: [Int]) async -> [Block] {
    let chunks = markdown.chunked(sizes: chunkSizes)
    let controller = MarkdownStreamController()
    let eventStream = await controller.events()

    Task {
        for chunk in chunks {
            await controller.append(chunk)
        }
        await controller.finish()
    }

    var reducerState = BlockReducer.ReducerState()
    for await event in eventStream {
        BlockReducer.apply(event, to: &reducerState)
    }

    return normalizedBlocks(reducerState.blocks)
}
