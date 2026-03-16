import QuillCore

extension Block {
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

enum FlowSegmentBuilder {

    // MARK: - Build

    static func build(from blocks: [Block]) -> [RenderNode] {
        var nodes: [RenderNode] = []
        var buffer: [Block] = []

        for block in blocks {
            if block.isFlowContent {
                buffer.append(block)
                if buffer.count >= flowSoftCap {
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

    static func frozenNodeCount(blocks: [Block], frozenBlockCount: Int) -> Int {
        guard frozenBlockCount > 0, blocks.isEmpty == false else { return 0 }

        let clampedFrozenCount = min(frozenBlockCount, blocks.count)
        var nodeCount = 0
        var pendingFlowCount = 0

        for (index, block) in blocks.enumerated() {
            if block.isFlowContent {
                pendingFlowCount += 1
                if pendingFlowCount >= flowSoftCap {
                    if index < clampedFrozenCount {
                        nodeCount += 1
                    }
                    pendingFlowCount = 0
                }
                continue
            }

            if pendingFlowCount > 0 {
                if index <= clampedFrozenCount {
                    nodeCount += 1
                }
                pendingFlowCount = 0
            }

            if index < clampedFrozenCount {
                nodeCount += 1
            }
        }

        if pendingFlowCount > 0, blocks.count <= clampedFrozenCount {
            nodeCount += 1
        }

        return nodeCount
    }

    // MARK: - Private

    private static let flowSoftCap = 10

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
