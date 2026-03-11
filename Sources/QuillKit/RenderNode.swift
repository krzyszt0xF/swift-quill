import Foundation
import QuillCore

enum RenderNode: Sendable {
    case codeBlock(language: String?, code: String)
    case flow(FlowSegment)
    case image(source: String?, title: String?)
    case table(columnAlignments: [Block.ColumnAlignment?],
               header: Block.TableRow,
               rows: [Block.TableRow])
}

extension RenderNode: Equatable {
    static func == (lhs: RenderNode, rhs: RenderNode) -> Bool {
        switch (lhs, rhs) {
        case let (.codeBlock(lLang, lCode), .codeBlock(rLang, rCode)):
            return lLang == rLang && lCode == rCode
        case let (.flow(lSegment), .flow(rSegment)):
            return lSegment == rSegment
        case let (.image(lSource, lTitle), .image(rSource, rTitle)):
            return lSource == rSource && lTitle == rTitle
        case let (.table(lAlign, lHeader, lRows), .table(rAlign, rHeader, rRows)):
            return lAlign == rAlign && lHeader == rHeader && lRows == rRows
        default:
            return false
        }
    }
}

extension RenderNode {
    struct FlowSegment: Sendable {
        let blocks: [Block]
        let id: UUID

        init(blocks: [Block], id: UUID = UUID()) {
            self.blocks = blocks
            self.id = id
        }
    }
}

extension RenderNode.FlowSegment: Equatable {
    static func == (lhs: RenderNode.FlowSegment, rhs: RenderNode.FlowSegment) -> Bool {
        lhs.blocks == rhs.blocks
    }
}
