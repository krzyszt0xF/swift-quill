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
                hasPendingStructure: detectPendingStructure(in: accumulatedText) != nil
            )
        }

        accumulatedText += chunk
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
        let pendingStructure = detectPendingStructure(in: accumulatedText)
        guard
            hasExceededDelay,
            pendingStructure == nil,
            let boundary = timeoutBoundary(from: lastSafePosition)
        else {
            return []
        }

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
    enum PendingStructureType {
        case codeBlock
        case table
    }

    mutating func commitCompleteModules() -> AppendResult {
        let startPosition = lastSafePosition
        if let _ = detectPendingStructure(in: accumulatedText) {
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
            lastSafePosition = 0
            return
        }

        guard let splitIndex = accumulatedText.index(
            accumulatedText.startIndex,
            offsetBy: lastSafePosition,
            limitedBy: accumulatedText.endIndex
        ) else {
            accumulatedText = ""
            lastSafePosition = 0
            return
        }

        accumulatedText = String(accumulatedText[splitIndex...])
        lastSafePosition = 0
    }

    func detectPendingStructure(in text: String) -> PendingStructureType? {
        let trimmedEnd = text.suffix(10)
        if trimmedEnd.contains("`") {
            let backtickSuffix = String(text.suffix(5))
            if backtickSuffix.hasSuffix("`"), !backtickSuffix.hasSuffix("```") {
                let backtickCount = backtickSuffix.reversed().prefix(while: { $0 == "`" }).count
                if backtickCount == 1 || backtickCount == 2 {
                    return .codeBlock
                }
            }
        }

        var isInsideFence = false
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                isInsideFence.toggle()
            }
        }

        if isInsideFence {
            return .codeBlock
        }

        if let lastNonEmpty = text.components(separatedBy: .newlines).last(where: {
            $0.trimmingCharacters(in: .whitespaces).isEmpty == false
        }) {
            let trimmed = lastNonEmpty.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("|"),
               trimmed.contains("|"),
               text.hasSuffix("\n\n") == false {
                return .table
            }
        }

        return nil
    }

    func findModuleBoundaries(from startPosition: Int) -> [Int] {
        let lines = accumulatedText.components(separatedBy: "\n")
        var currentPosition = 0
        var h1Positions: [Int] = []
        var h2Positions: [Int] = []
        var isInsideCodeBlock = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                isInsideCodeBlock.toggle()
            }

            if !isInsideCodeBlock, currentPosition >= startPosition {
                if trimmed.hasPrefix("# "), !trimmed.hasPrefix("## ") {
                    h1Positions.append(currentPosition)
                } else if trimmed.hasPrefix("## "), !trimmed.hasPrefix("### ") {
                    h2Positions.append(currentPosition)
                }
            }

            currentPosition += line.count + (index < lines.count - 1 ? 1 : 0)
        }

        let headingPositions: [Int]
        if h1Positions.count >= 2 {
            headingPositions = h1Positions
        } else if h2Positions.count >= 2 {
            headingPositions = h2Positions
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

            if let paragraphBoundary = lastParagraphBoundary(from: startPosition) {
                boundaries.append(paragraphBoundary)
            }
        } else if headingPositions.count == 1 {
            if let paragraphBoundary = lastParagraphBoundary(from: startPosition) {
                boundaries.append(paragraphBoundary)
            }
        } else if let paragraphBoundary = lastParagraphBoundary(from: startPosition) {
            boundaries.append(paragraphBoundary)
        }

        return Array(Set(boundaries)).sorted()
    }

    func lastParagraphBoundary(from startPosition: Int) -> Int? {
        guard startPosition < accumulatedText.count else { return nil }

        let remaining = rawText(from: startPosition, to: accumulatedText.count)
        guard
            remaining.count >= configuration.minModuleLength * 2,
            let range = remaining.range(of: "\n\n", options: .backwards)
        else { return nil }

        let distance = remaining.distance(from: remaining.startIndex, to: range.upperBound)
        let boundary = startPosition + distance
        guard boundary > startPosition else { return nil }
        
        return boundary
    }

    func timeoutBoundary(from startPosition: Int) -> Int? {
        guard startPosition < accumulatedText.count else { return nil }

        let remainingText = rawText(from: startPosition, to: accumulatedText.count)
        let minimumSafeTimeoutLength = configuration.minModuleLength * 2
        let singleNewlineThreshold = configuration.minModuleLength * 4
        let fullFlushThreshold = configuration.minModuleLength * 8

        guard remainingText.count >= minimumSafeTimeoutLength else {
            return nil
        }

        if let range = remainingText.range(of: "\n\n", options: .backwards) {
            let distance = remainingText.distance(from: remainingText.startIndex, to: range.upperBound)
            return startPosition + distance
        }

        if remainingText.count >= singleNewlineThreshold,
           let range = remainingText.range(of: "\n", options: .backwards) {
            let distance = remainingText.distance(from: remainingText.startIndex, to: range.upperBound)
            return startPosition + distance
        }

        if remainingText.count >= fullFlushThreshold {
            return accumulatedText.count
        }

        return nil
    }

    func rawText(from start: Int, to end: Int) -> String {
        guard start >= 0, start < end, end <= accumulatedText.count else { return "" }
        guard
            let startIndex = accumulatedText.index(accumulatedText.startIndex, offsetBy: start, limitedBy: accumulatedText.endIndex),
            let endIndex = accumulatedText.index(accumulatedText.startIndex, offsetBy: end, limitedBy: accumulatedText.endIndex),
            startIndex < endIndex
        else {
            return ""
        }

        return String(accumulatedText[startIndex..<endIndex])
    }
}
