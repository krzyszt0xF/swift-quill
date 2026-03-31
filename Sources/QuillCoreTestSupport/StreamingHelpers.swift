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
        
        return normalizeCollectedEvents(collectedEvents)
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

private func normalizeCollectedEvents(_ events: [ParserEvent]) -> [ParserEvent] {
    var normalized: [ParserEvent] = []

    for event in events {
        switch event {
        case let .codeBlockText(text):
            if case let .codeBlockText(existing)? = normalized.last {
                normalized.removeLast()
                normalized.append(.codeBlockText(existing + text))
            } else {
                normalized.append(event)
            }
        case let .text(text):
            if case let .text(existing)? = normalized.last {
                normalized.removeLast()
                normalized.append(.text(existing + text))
            } else {
                normalized.append(event)
            }
        default:
            normalized.append(event)
        }
    }

    return normalized
}
