struct PartialLinePreviewer {
    static func makePreview(
        for partialLine: String,
        previousPreview: StreamBuffer.PartialPreview?,
        blockState: StreamBuffer.BlockState,
        allowHeadingTransitionFromParagraph: Bool
    ) -> PreviewResult? {
        guard partialLine.isEmpty == false else { return nil }

        switch blockState {
        case let .codeFence(marker, _, indentToStrip):
            return makeCodeFencePreview(
                for: partialLine,
                indentToStrip: indentToStrip,
                marker: marker,
                previousPreview: previousPreview,
                blockState: blockState
            )
        case .idle:
            return makeIdlePreview(for: partialLine)
        case .paragraph:
            return makeParagraphPreview(
                for: partialLine,
                previousPreview: previousPreview,
                allowHeadingTransition: allowHeadingTransitionFromParagraph
            )
        case .heading:
            return makeHeadingPreview(
                for: partialLine,
                previousPreview: previousPreview
            )
        case .tableCandidate:
            return nil
        case .table:
            return makeTablePreview(
                for: partialLine,
                previousPreview: previousPreview
            )
        }
    }

    static func makeRemainderEvents(
        for line: String,
        preview: StreamBuffer.PartialPreview
    ) -> [ParserEvent]? {
        switch preview {
        case let .codeBlockText(emittedText, indentToStrip):
            return makeRemainingCodeText(
                fullText: line.removingLeadingIndent(width: indentToStrip),
                emittedText: emittedText,
                appendsNewline: true
            )
        case let .paragraph(emittedText, isContinuation):
            return makeRemainingText(
                fullText: line.makeParagraphPreviewText(isContinuation: isContinuation),
                emittedText: emittedText
            )
        case let .heading(level, emittedText):
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let fullText: String
            if let parsedLevel = StreamLineClassifier.parseHeadingPrefix(trimmed), parsedLevel == level {
                fullText = StreamLineClassifier.extractHeadingContent(trimmed, level: level)
            } else {
                fullText = emittedText
            }

            var events = makeRemainingText(
                fullText: fullText,
                emittedText: emittedText
            )
            events.append(.endHeading)
            return events
        case .tableRow:
            // Table row previews are structural rather than diffable text updates,
            // so the completed line does not emit a separate remainder payload.
            return []
        }
    }
}

extension PartialLinePreviewer {
    struct PreviewResult {
        let blockState: StreamBuffer.BlockState
        let events: [ParserEvent]
        let preview: StreamBuffer.PartialPreview
    }
}

private extension PartialLinePreviewer {
    static func makeCodeFencePreview(
        for partialLine: String,
        indentToStrip: Int,
        marker: Character,
        previousPreview: StreamBuffer.PartialPreview?,
        blockState: StreamBuffer.BlockState
    ) -> PreviewResult? {
        guard partialLine.isClosingFencePrefix(of: marker) == false else {
            return nil
        }

        let normalizedLine = partialLine.removingLeadingIndent(width: indentToStrip)
        guard normalizedLine.isEmpty == false else { return nil }

        let emittedText: String
        if case let .codeBlockText(existingText, _)? = previousPreview {
            emittedText = existingText
        } else {
            emittedText = ""
        }

        let events = makeRemainingCodeText(
            fullText: normalizedLine,
            emittedText: emittedText,
            appendsNewline: false
        )

        return PreviewResult(
            blockState: blockState,
            events: events,
            preview: .codeBlockText(emittedText: normalizedLine, indentToStrip: indentToStrip)
        )
    }

    static func makeIdlePreview(for partialLine: String) -> PreviewResult? {
        let trimmed = partialLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.isEmpty == false else { return nil }
        guard partialLine.isAmbiguousIdlePreviewPrefix == false else { return nil }

        if let level = StreamLineClassifier.parseHeadingPrefix(trimmed) {
            let content = StreamLineClassifier.extractHeadingContent(trimmed, level: level)
            guard content.isEmpty == false else { return nil }

            return PreviewResult(
                blockState: .heading,
                events: [.startHeading(level: level), .text(content)],
                preview: .heading(level: level, emittedText: content)
            )
        }

        if StreamLineClassifier.parseFenceOpener(trimmed) != nil
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
            blockState: .paragraph,
            events: events,
            preview: .paragraph(emittedText: trimmed, isContinuation: false)
        )
    }

    static func makeParagraphPreview(
        for partialLine: String,
        previousPreview: StreamBuffer.PartialPreview?,
        allowHeadingTransition: Bool
    ) -> PreviewResult? {
        let trimmed = partialLine.trimmingCharacters(in: .whitespaces)

        if allowHeadingTransition, let level = StreamLineClassifier.parseHeadingPrefix(trimmed) {
            let content = StreamLineClassifier.extractHeadingContent(trimmed, level: level)
            guard content.isEmpty == false else { return nil }

            return PreviewResult(
                blockState: .heading,
                events: [.endParagraph, .startHeading(level: level), .text(content)],
                preview: .heading(level: level, emittedText: content)
            )
        }

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
            blockState: .paragraph,
            events: events,
            preview: .paragraph(emittedText: previewText, isContinuation: isContinuation)
        )
    }

    static func makeHeadingPreview(
        for partialLine: String,
        previousPreview: StreamBuffer.PartialPreview?
    ) -> PreviewResult? {
        let trimmed = partialLine.trimmingCharacters(in: .whitespaces)
        guard let level = StreamLineClassifier.parseHeadingPrefix(trimmed) else { return nil }

        let fullText = StreamLineClassifier.extractHeadingContent(trimmed, level: level)
        guard fullText.isEmpty == false else { return nil }

        if case let .heading(previousLevel, emittedText)? = previousPreview,
           previousLevel == level {
            return PreviewResult(
                blockState: .heading,
                events: makeRemainingText(
                    fullText: fullText,
                    emittedText: emittedText
                ),
                preview: .heading(level: level, emittedText: fullText)
            )
        }

        return PreviewResult(
            blockState: .heading,
            events: [.startHeading(level: level), .text(fullText)],
            preview: .heading(level: level, emittedText: fullText)
        )
    }

    static func makeTablePreview(
        for partialLine: String,
        previousPreview: StreamBuffer.PartialPreview?
    ) -> PreviewResult? {
        let trimmed = partialLine.trimmedLineForTablePreview
        guard trimmed.hasPrefix("|"), trimmed.hasSuffix("|") else { return nil }
        guard StreamLineClassifier.isTableSeparator(trimmed) == false else { return nil }
        let cells = StreamLineClassifier.parseTableCells(trimmed)
        guard cells.count >= 2 else { return nil }

        if case let .tableRow(emittedLine)? = previousPreview, emittedLine == trimmed {
            return PreviewResult(
                blockState: .table,
                events: [],
                preview: .tableRow(emittedLine: emittedLine)
            )
        }

        return PreviewResult(
            blockState: .table,
            events: [.tableRow(cells)],
            preview: .tableRow(emittedLine: trimmed)
        )
    }

    static func makeRemainingCodeText(
        fullText: String,
        emittedText: String,
        appendsNewline: Bool
    ) -> [ParserEvent] {
        guard let suffix = fullText.makeRemainingSuffix(after: emittedText) else {
            guard appendsNewline, fullText == emittedText else { return [] }
            return [.codeBlockText("\n")]
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
    var trimmedLineForTablePreview: String {
        trimmingCharacters(in: .whitespaces)
    }

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

        if trimmed.allSatisfy(\.isNumber), trimmed.count <= 3 {
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
