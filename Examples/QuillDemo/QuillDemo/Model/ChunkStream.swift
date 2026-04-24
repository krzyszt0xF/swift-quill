import Foundation

enum ChunkStream {
    static func stream(
        for scenario: Scenario,
        chunkDelayMs: Double
    ) -> AsyncStream<String> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                let chunks = splitIntoChunks(scenario.loadContent())
                let delayNs = UInt64(max(0, chunkDelayMs) * 1_000_000)
                for chunk in chunks {
                    if Task.isCancelled { break }
                    if delayNs > 0 {
                        try? await Task.sleep(nanoseconds: delayNs)
                    }
                    if Task.isCancelled { break }
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func splitIntoChunks(_ content: String) -> [String] {
        var chunks: [String] = []
        var current = ""
        var wordsInChunk = 0
        let targetWords = 5

        for character in content {
            current.append(character)
            if character == " " {
                wordsInChunk += 1
                if wordsInChunk >= targetWords {
                    chunks.append(current)
                    current = ""
                    wordsInChunk = 0
                }
            } else if character == "\n", wordsInChunk >= targetWords - 2 {
                chunks.append(current)
                current = ""
                wordsInChunk = 0
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }
}
