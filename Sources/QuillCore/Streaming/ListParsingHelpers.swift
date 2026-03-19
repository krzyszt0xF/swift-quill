enum ListParsingHelpers {
    static func closeOpenLists(_ listStack: inout [StreamBuffer.ListContext]) -> [ParserEvent] {
        guard !listStack.isEmpty else { return [] }

        var events: [ParserEvent] = [.endParagraph, .endListItem, .endList]
        listStack.removeLast()

        while !listStack.isEmpty {
            events.append(.endListItem)
            events.append(.endList)
            listStack.removeLast()
        }

        return events
    }

    static func processListItemLine(
        _ item: StreamLineClassifier.ListItemContent,
        marker: StreamLineClassifier.ListMarker,
        listStack: inout [StreamBuffer.ListContext]
    ) -> [ParserEvent] {
        guard let currentList = listStack.last else {
            listStack = [StreamBuffer.ListContext(indent: marker.indent, ordered: marker.ordered)]
            return [.startList(ordered: marker.ordered), item.startEvent, .startParagraph, .text(item.content)]
        }

        if marker.indent > currentList.indent {
            listStack.append(StreamBuffer.ListContext(indent: marker.indent, ordered: marker.ordered))
            return [.endParagraph, .startList(ordered: marker.ordered), item.startEvent, .startParagraph, .text(item.content)]
        }

        var events: [ParserEvent] = [.endParagraph, .endListItem]
        while let activeList = listStack.last,
              marker.indent < activeList.indent {
            events.append(.endList)
            listStack.removeLast()

            if !listStack.isEmpty {
                events.append(.endListItem)
            }
        }

        guard let targetList = listStack.last else {
            listStack = [StreamBuffer.ListContext(indent: marker.indent, ordered: marker.ordered)]
            events.append(.startList(ordered: marker.ordered))
            events.append(item.startEvent)
            events.append(.startParagraph)
            events.append(.text(item.content))
            return events
        }

        if marker.indent == targetList.indent,
           marker.ordered == targetList.ordered {
            events.append(item.startEvent)
            events.append(.startParagraph)
            events.append(.text(item.content))
            return events
        }

        if marker.indent == targetList.indent {
            events.append(.endList)
            listStack.removeLast()
        }

        listStack.append(StreamBuffer.ListContext(indent: marker.indent, ordered: marker.ordered))
        events.append(.startList(ordered: marker.ordered))
        events.append(item.startEvent)
        events.append(.startParagraph)
        events.append(.text(item.content))
        
        return events
    }
}
