struct PartialLinePreviewer {
    static func makePreview(
        for partialLine: String,
        previousPreview: StreamBuffer.PartialPreview?,
        state: StreamBuffer.State
    ) -> PreviewResult? {
        guard partialLine.isEmpty == false else { return nil }

        switch state {
        case let .codeFence(marker, _):
            return makeCodeFencePreview(
                for: partialLine,
                marker: marker,
                previousPreview: previousPreview,
                state: state
            )
        case .idle:
            return makeIdlePreview(for: partialLine)
        case .paragraph:
            return makeParagraphPreview(
                for: partialLine,
                previousPreview: previousPreview
            )
        case .heading, .list, .table, .tableCandidate:
            return nil
        }
    }

    static func makeRemainderEvents(
        for line: String,
        preview: StreamBuffer.PartialPreview
    ) -> [ParserEvent]? {
        switch preview {
        case let .codeBlockText(emittedText):
            return makeRemainingCodeText(
                fullText: line,
                emittedText: emittedText,
                appendsNewline: true
            )
        case let .paragraph(emittedText, isContinuation):
            return makeRemainingText(
                fullText: line.makeParagraphPreviewText(isContinuation: isContinuation),
                emittedText: emittedText
            )
        }
    }
}

extension PartialLinePreviewer {
    struct PreviewResult {
        let events: [ParserEvent]
        let preview: StreamBuffer.PartialPreview
        let state: StreamBuffer.State
    }
}

private extension PartialLinePreviewer {
    static func makeCodeFencePreview(
        for partialLine: String,
        marker: Character,
        previousPreview: StreamBuffer.PartialPreview?,
        state: StreamBuffer.State
    ) -> PreviewResult? {
        guard partialLine.isClosingFencePrefix(of: marker) == false else {
            return nil
        }

        let emittedText: String
        if case let .codeBlockText(existingText)? = previousPreview {
            emittedText = existingText
        } else {
            emittedText = ""
        }

        let events = makeRemainingCodeText(
            fullText: partialLine,
            emittedText: emittedText,
            appendsNewline: false
        )

        return PreviewResult(
            events: events,
            preview: .codeBlockText(emittedText: partialLine),
            state: state
        )
    }

    static func makeIdlePreview(for partialLine: String) -> PreviewResult? {
        let trimmed = partialLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.isEmpty == false else { return nil }
        guard partialLine.isAmbiguousIdlePreviewPrefix == false else { return nil }

        if StreamLineClassifier.parseFenceOpener(trimmed) != nil
            || StreamLineClassifier.parseHeadingPrefix(trimmed) != nil
            || StreamLineClassifier.isThematicBreak(trimmed)
            || StreamLineClassifier.parseListMarker(partialLine) != nil
            || trimmed.hasPrefix(">")
            || (trimmed.contains("|") && trimmed.hasPrefix("|")) {
            return nil
        }

        var events: [ParserEvent] = [.startParagraph]
        if trimmed.isEmpty == false {
            events.append(.text(trimmed))
        }

        return PreviewResult(
            events: events,
            preview: .paragraph(emittedText: trimmed, isContinuation: false),
            state: .paragraph
        )
    }

    static func makeParagraphPreview(
        for partialLine: String,
        previousPreview: StreamBuffer.PartialPreview?
    ) -> PreviewResult? {
        let emittedText: String
        let isContinuation: Bool

        if case let .paragraph(existingText, existingContinuation)? = previousPreview {
            emittedText = existingText
            isContinuation = existingContinuation
        } else {
            emittedText = ""
            isContinuation = true
        }

        let previewText = partialLine.makeParagraphPreviewText(isContinuation: isContinuation)
        let events = makeRemainingText(
            fullText: previewText,
            emittedText: emittedText
        )

        return PreviewResult(
            events: events,
            preview: .paragraph(emittedText: previewText, isContinuation: isContinuation),
            state: .paragraph
        )
    }

    static func makeRemainingCodeText(
        fullText: String,
        emittedText: String,
        appendsNewline: Bool
    ) -> [ParserEvent] {
        guard let suffix = fullText.makeRemainingSuffix(after: emittedText) else {
            return []
        }

        let output = appendsNewline ? suffix + "\n" : suffix
        return [.codeBlockText(output)]
    }

    static func makeRemainingSuffix(
        fullText: String,
        emittedText: String
    ) -> String? {
        fullText.makeRemainingSuffix(after: emittedText)
    }

    static func makeRemainingText(
        fullText: String,
        emittedText: String
    ) -> [ParserEvent] {
        guard let suffix = makeRemainingSuffix(
            fullText: fullText,
            emittedText: emittedText
        ) else {
            return []
        }

        return [.text(suffix)]
    }
}

private extension String {
    var isAmbiguousIdlePreviewPrefix: Bool {
        let trimmed = trimmingCharacters(in: .whitespaces)
        guard trimmed.isEmpty == false else { return false }

        if trimmed.allSatisfy({ $0 == "#" }) && trimmed.count <= 6 {
            return true
        }

        if trimmed.allSatisfy({ $0 == "`" || $0 == "~" }) && trimmed.count < 3 {
            return true
        }

        if trimmed == "-" || trimmed == "*" || trimmed == "+" {
            return true
        }

        if trimmed == "--" || trimmed == "**" || trimmed == "__" {
            return true
        }

        if trimmed.last == "." || trimmed.last == ")" {
            let prefix = trimmed.dropLast()
            return prefix.isEmpty == false && prefix.allSatisfy(\.isNumber)
        }

        return false
    }

    func isClosingFencePrefix(of marker: Character) -> Bool {
        let trimmed = trimmingCharacters(in: .whitespaces)
        guard trimmed.isEmpty == false else { return false }
        return trimmed.allSatisfy { $0 == marker }
    }

    func makeParagraphPreviewText(isContinuation: Bool) -> String {
        let trimmed = trimmingCharacters(in: .whitespaces)
        if isContinuation {
            return StreamLineClassifier.makeContinuationText(from: trimmed)
        }

        return trimmed
    }

    func makeRemainingSuffix(after emittedText: String) -> String? {
        guard count >= emittedText.count else { return nil }

        let suffixStart = index(startIndex, offsetBy: emittedText.count)
        let suffix = String(self[suffixStart...])
        guard suffix.isEmpty == false else { return nil }

        return suffix
    }
}
