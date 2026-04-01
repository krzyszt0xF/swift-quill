extension StreamBuffer {
    mutating func emitPreviewRemainder(for line: String) -> [ParserEvent]? {
        guard let partialPreview = state.partialPreview else { return nil }

        defer { state.partialPreview = nil }

        if case .heading = partialPreview {
            state.blockState = .idle
        }

        return PartialLinePreviewer.makeRemainderEvents(
            for: line,
            preview: partialPreview
        )
    }

    mutating func previewPartialLineIfNeeded() -> [ParserEvent] {
        guard shouldPreviewPartialLine else {
            clearPartialPreview()
            return []
        }

        guard let preview = makePartialPreview() else {
            clearPartialPreview()
            return []
        }

        applyPartialPreview(preview)
        return preview.events
    }

    var shouldPreviewPartialLine: Bool {
        state.partialLine.isEmpty == false
            && StreamLineClassifier.parseBlockquotePrefix(state.partialLine) == nil
            && isPotentialNestedListMarkerPreview == false
            && shouldSuppressPartialPreviewForListEmbeddedBlock == false
    }

    var isPotentialNestedListMarkerPreview: Bool {
        !state.listStack.isEmpty
            && StreamLineClassifier.isPotentialListMarkerPrefix(state.partialLine)
    }

    func makePartialPreview() -> PartialLinePreviewer.PreviewResult? {
        PartialLinePreviewer.makePreview(
            for: state.partialLine,
            previousPreview: state.partialPreview,
            blockState: state.blockState,
            allowHeadingTransitionFromParagraph: state.listStack.isEmpty
        )
    }

    mutating func applyPartialPreview(_ preview: PartialLinePreviewer.PreviewResult) {
        state.partialPreview = preview.preview
        state.blockState = preview.blockState

        if !state.listStack.isEmpty, case .paragraph = preview.blockState {
            state.hasOpenListParagraph = true
        }
    }

    mutating func clearPartialPreview() {
        state.partialPreview = nil
    }

    var shouldSuppressPartialPreviewForListEmbeddedBlock: Bool {
        guard state.blockState != .table else { return false }

        guard
            let currentList = state.listStack.last,
            StreamLineClassifier.isListEmbeddedBlockCandidate(
                state.partialLine,
                currentListIndent: currentList.indent
            )
        else {
            return false
        }

        let trimmed = state.partialLine.trimmingCharacters(in: .whitespaces)
        if trimmed.first == "`" || trimmed.first == "~" {
            return true
        }

        return trimmed.hasPrefix("|") && trimmed.contains("|")
    }
}
