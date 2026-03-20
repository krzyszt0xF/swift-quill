package extension String {
    func chunked(sizes: [Int]) -> [String] {
        let characters = Array(self)
        var characterIndex = 0
        var sizeIndex = 0
        var chunks: [String] = []

        while characterIndex < characters.count {
            let chunkSize = sizes[sizeIndex % sizes.count]
            let chunkEndIndex = min(characterIndex + max(1, chunkSize), characters.count)
            chunks.append(String(characters[characterIndex..<chunkEndIndex]))
            characterIndex = chunkEndIndex
            sizeIndex += 1
        }

        return chunks
    }
}
