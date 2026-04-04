import QuillCore
import QuillSharedTestSupport

package extension Array where Element == ParserEvent {
    func reduceToBlocks() -> [Block] {
        var reducerState = BlockReducer.ReducerState()
        for event in self {
            BlockReducer.apply(event, to: &reducerState)
        }
        return reducerState.blocks.normalizedBlocks()
    }
}

package extension MarkdownStreamController {
    func collectEvents(feeding chunks: [String]) async -> [ParserEvent] {
        let eventStream = events()

        Task {
            for chunk in chunks {
                append(chunk)
            }
            finish()
        }

        var collectedEvents: [ParserEvent] = []
        for await event in eventStream {
            collectedEvents.append(event)
        }

        return collectedEvents.normalizedEvents()
    }

    static func streamAndReduce(_ markdown: String, chunkSizes: [Int]) async -> [Block] {
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

        return reducerState.blocks.normalizedBlocks()
    }
}

private extension Array where Element == ParserEvent {
    func normalizedEvents() -> [ParserEvent] {
        var normalized: [ParserEvent] = []

        for event in self {
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
}
