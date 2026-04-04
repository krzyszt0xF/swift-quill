import Foundation

package struct ModuleStreamGateConfiguration: Equatable, Sendable {
    package var minModuleLength: Int
    package var maxBufferingDelay: TimeInterval

    package init(
        minModuleLength: Int = 50,
        maxBufferingDelay: TimeInterval = 1.5
    ) {
        self.minModuleLength = max(1, minModuleLength)
        self.maxBufferingDelay = max(0.1, maxBufferingDelay)
    }
}

package struct ModuleStreamGate: Sendable {
    private var accumulatedText = ""
    private var structureIndex = BufferStructureIndex()
    private var configuration: ModuleStreamGateConfiguration
    private var lastSafePosition = 0
    private var pendingSince: TimeInterval?

    package init(configuration: ModuleStreamGateConfiguration = .init()) {
        self.configuration = configuration
    }

    package var hasPendingText: Bool {
        accumulatedText.count > lastSafePosition
    }

    package mutating func reset() {
        accumulatedText = ""
        structureIndex = .init()
        lastSafePosition = 0
        pendingSince = nil
    }

    package mutating func updateConfiguration(_ configuration: ModuleStreamGateConfiguration) {
        self.configuration = configuration
    }

    package func timeUntilForcedCommit(now: TimeInterval) -> TimeInterval? {
        guard let pendingSince, hasPendingText else { return nil }
        return max(0, configuration.maxBufferingDelay - (now - pendingSince))
    }

    package mutating func append(_ chunk: String, now: TimeInterval) -> AppendResult {
        guard !chunk.isEmpty else {
            return AppendResult(
                committedChunks: [],
                hasPendingText: hasPendingText,
                hasPendingStructure: structureIndex.pendingStructure != nil
            )
        }

        accumulatedText += chunk
        rebuildStructureIndex()
        if pendingSince == nil, hasPendingText {
            pendingSince = now
        }

        let result = commitCompleteModules()
        if result.committedChunks.isEmpty == false {
            pendingSince = hasPendingText ? now : nil
        }

        return result
    }

    package mutating func commitIfOverdue(now: TimeInterval) -> [String] {
        let hasExceededDelay: Bool
        if let pendingSince {
            hasExceededDelay = now - pendingSince >= configuration.maxBufferingDelay
        } else {
            hasExceededDelay = false
        }
        guard hasExceededDelay else {
            return []
        }

        guard
            structureIndex.pendingStructure == nil,
            let boundary = makeTimeoutCommitBoundary(from: lastSafePosition)
        else { return [] }

        let committed = commit(upTo: boundary)
        if committed.isEmpty == false {
            compactCommittedPrefix()
        }
        self.pendingSince = hasPendingText ? now : nil

        return committed
    }

    package mutating func flushRemaining() -> String {
        let remaining = rawText(from: lastSafePosition, to: accumulatedText.count)
        accumulatedText = ""
        structureIndex = .init()
        lastSafePosition = 0
        pendingSince = nil

        return remaining
    }

    package struct AppendResult: Equatable, Sendable {
        package var committedChunks: [String]
        package var hasPendingText: Bool
        package var hasPendingStructure: Bool

        package init(
            committedChunks: [String],
            hasPendingText: Bool,
            hasPendingStructure: Bool
        ) {
            self.committedChunks = committedChunks
            self.hasPendingText = hasPendingText
            self.hasPendingStructure = hasPendingStructure
        }
    }
}

private extension ModuleStreamGate {
    struct BufferStructureIndex: Sendable {
        var h1Positions: [Int] = []
        var h2Positions: [Int] = []
        var newlineBoundaries: [Int] = []
        var paragraphBoundaries: [Int] = []
        var pendingStructure: PendingStructureType?

        init() {}

        init(from text: String) {
            guard !text.isEmpty else { return }

            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            var currentPosition = 0
            var isInsideFence = false
            var lastNonEmptyTrimmedLine: String?

            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.isEmpty == false {
                    lastNonEmptyTrimmedLine = trimmed
                }

                if !isInsideFence {
                    if trimmed.hasPrefix("# "), !trimmed.hasPrefix("## ") {
                        h1Positions.append(currentPosition)
                    } else if trimmed.hasPrefix("## "), !trimmed.hasPrefix("### ") {
                        h2Positions.append(currentPosition)
                    }
                }

                if Self.isFenceDelimiter(trimmed) {
                    isInsideFence.toggle()
                }

                guard index < lines.count - 1 else {
                    currentPosition += line.count
                    continue
                }

                currentPosition += line.count + 1
                newlineBoundaries.append(currentPosition)
                if line.isEmpty {
                    paragraphBoundaries.append(currentPosition)
                }
            }

            if Self.hasTrailingFenceStart(in: text) || isInsideFence {
                pendingStructure = .codeBlock
                return
            }

            guard
                let lastNonEmptyTrimmedLine,
                text.hasSuffix("\n\n") == false,
                lastNonEmptyTrimmedLine.hasPrefix("|"),
                lastNonEmptyTrimmedLine.contains("|")
            else { return }

            pendingStructure = .table
        }

        private static func hasTrailingFenceStart(in text: String) -> Bool {
            let suffix = text.suffix(5)
            guard suffix.contains("`") else { return false }

            let candidate = String(suffix)
            guard candidate.hasSuffix("`"), candidate.hasSuffix("```") == false else {
                return false
            }

            let backtickCount = candidate.reversed().prefix(while: { $0 == "`" }).count
            return backtickCount == 1 || backtickCount == 2
        }

        private static func isFenceDelimiter(_ trimmedLine: String) -> Bool {
            trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~")
        }
    }

    enum PendingStructureType {
        case codeBlock
        case table
    }

    mutating func commitCompleteModules() -> AppendResult {
        let startPosition = lastSafePosition
        if structureIndex.pendingStructure != nil {
            return AppendResult(
                committedChunks: [],
                hasPendingText: hasPendingText,
                hasPendingStructure: true
            )
        }

        let boundaries = findModuleBoundaries(from: startPosition)
        if boundaries.isEmpty {
            return AppendResult(
                committedChunks: [],
                hasPendingText: hasPendingText,
                hasPendingStructure: false
            )
        }

        var committed: [String] = []
        for boundary in boundaries where boundary > lastSafePosition {
            committed.append(contentsOf: commit(upTo: boundary))
        }

        if committed.isEmpty == false {
            compactCommittedPrefix()
        }

        return AppendResult(
            committedChunks: committed,
            hasPendingText: hasPendingText,
            hasPendingStructure: false
        )
    }

    mutating func commit(upTo boundary: Int) -> [String] {
        guard boundary > lastSafePosition else { return [] }

        let module = rawText(from: lastSafePosition, to: boundary)
        lastSafePosition = boundary
        guard module.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return []
        }

        return [module]
    }

    mutating func compactCommittedPrefix() {
        guard lastSafePosition > 0 else { return }

        if lastSafePosition >= accumulatedText.count {
            accumulatedText = ""
            structureIndex = .init()
            lastSafePosition = 0
            return
        }

        guard let splitIndex = accumulatedText.index(
            accumulatedText.startIndex,
            offsetBy: lastSafePosition,
            limitedBy: accumulatedText.endIndex
        ) else {
            accumulatedText = ""
            structureIndex = .init()
            lastSafePosition = 0
            return
        }

        accumulatedText = String(accumulatedText[splitIndex...])
        rebuildStructureIndex()
        lastSafePosition = 0
    }

    func findModuleBoundaries(from startPosition: Int) -> [Int] {
        let filteredH1Positions = structureIndex.h1Positions.filter { $0 >= startPosition }
        let filteredH2Positions = structureIndex.h2Positions.filter { $0 >= startPosition }
        let headingPositions: [Int]

        if filteredH1Positions.count >= 2 {
            headingPositions = filteredH1Positions
        } else if filteredH2Positions.count >= 2 {
            headingPositions = filteredH2Positions
        } else {
            headingPositions = []
        }

        var boundaries: [Int] = []
        if headingPositions.count >= 2 {
            for index in 1..<headingPositions.count {
                let boundary = headingPositions[index]
                if boundary > startPosition {
                    boundaries.append(boundary)
                }
            }
        }

        if let paragraphBoundary = lastParagraphBoundary(from: startPosition) {
            boundaries.append(paragraphBoundary)
        }

        return Array(Set(boundaries)).sorted()
    }

    func lastParagraphBoundary(from startPosition: Int) -> Int? {
        guard accumulatedText.count - startPosition >= configuration.minModuleLength * 2 else {
            return nil
        }

        return structureIndex.paragraphBoundaries.last { $0 > startPosition }
    }

    func makeTimeoutCommitBoundary(from startPosition: Int) -> Int? {
        guard startPosition < accumulatedText.count else { return nil }

        let remainingLength = accumulatedText.count - startPosition
        let minimumSafeTimeoutLength = configuration.minModuleLength * 2
        let singleNewlineThreshold = configuration.minModuleLength * 4
        let fullFlushThreshold = configuration.minModuleLength * 8

        guard remainingLength >= minimumSafeTimeoutLength else {
            return nil
        }

        if let boundary = structureIndex.paragraphBoundaries.last(where: { $0 > startPosition }) {
            return boundary
        }

        if remainingLength >= singleNewlineThreshold,
           let boundary = structureIndex.newlineBoundaries.last(where: { $0 > startPosition }) {
            return boundary
        }

        if remainingLength >= fullFlushThreshold {
            return accumulatedText.count
        }

        return nil
    }

    func rawText(from start: Int, to end: Int) -> String {
        guard start >= 0, start < end, end <= accumulatedText.count else { return "" }
        guard
            let startIndex = accumulatedText.index(
                accumulatedText.startIndex, offsetBy: start, limitedBy: accumulatedText.endIndex
            ),
            let endIndex = accumulatedText.index(
                accumulatedText.startIndex, offsetBy: end, limitedBy: accumulatedText.endIndex
            ),
            startIndex < endIndex
        else {
            return ""
        }

        return String(accumulatedText[startIndex..<endIndex])
    }

    mutating func rebuildStructureIndex() {
        structureIndex = BufferStructureIndex(from: accumulatedText)
    }
}
