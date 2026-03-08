import QuillCore

public extension Block {
    var isFlowContent: Bool {
        switch self {
        case .blockquote:
            return true
        case .codeBlock:
            return false
        case .heading:
            return true
        case .htmlBlock:
            return true
        case .orderedList:
            return true
        case .paragraph:
            return true
        case .table:
            return false
        case .thematicBreak:
            return true
        case .unorderedList:
            return true
        }
    }
}

/// Groups Block AST into RenderNodes for efficient TextKit 2 rendering.
public enum FlowSegmentBuilder {

    // MARK: - Public

    public static func build(from blocks: [Block]) -> [RenderNode] {
        var nodes: [RenderNode] = []
        var buffer: [Block] = []
        let softCap = 10

        for block in blocks {
            if block.isFlowContent {
                buffer.append(block)
                if buffer.count >= softCap {
                    flush(&buffer, into: &nodes)
                }
            } else {
                flush(&buffer, into: &nodes)
                nodes.append(structuralNode(for: block))
            }
        }

        flush(&buffer, into: &nodes)
        return nodes
    }

    // MARK: - Private

    private static func flush(_ buffer: inout [Block], into nodes: inout [RenderNode]) {
        guard !buffer.isEmpty else { return }
        nodes.append(.flow(RenderNode.FlowSegment(blocks: buffer)))
        buffer.removeAll()
    }

    private static func structuralNode(for block: Block) -> RenderNode {
        switch block {
        case let .codeBlock(language, code):
            return .codeBlock(language: language, code: code)
        case let .table(alignments, header, rows):
            return .table(columnAlignments: alignments, header: header, rows: rows)
        default:
            assertionFailure("structuralNode called with flow content: \(block)")
            return .flow(RenderNode.FlowSegment(blocks: [block]))
        }
    }
}
