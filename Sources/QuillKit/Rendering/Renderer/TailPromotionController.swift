import QuillCore
import UIKit

@MainActor
enum TailPromotionController {
    static func checkCompatibility(tail: Block, frozen: Block) -> Bool {
        if tail == frozen {
            return true
        }

        switch (tail, frozen) {
        case let (.codeBlock(tailLanguage, tailCode), .codeBlock(frozenLanguage, frozenCode)):
            return tailLanguage == frozenLanguage
                && (frozenCode.hasPrefix(tailCode) || tailCode.hasPrefix(frozenCode))
        case let (.table(_, tailHeader, tailRows), .table(_, frozenHeader, frozenRows)):
            return tailHeader.cells.count == frozenHeader.cells.count
                && frozenRows.count >= tailRows.count
        default:
            return checkFlowCompatibility(tail: tail, frozen: frozen)
        }
    }

    static func prepareTailForPromotion(
        tailView: UIView,
        tailBlock: Block,
        frozenBlock: Block
    ) {
        switch (tailBlock, frozenBlock) {
        case (.codeBlock, let .codeBlock(_, frozenCode)):
            if let codeBlockView = tailView as? CodeBlockView {
                codeBlockView.updateCode(frozenCode)
            }
        case let (.table(_, _, _), .table(_, header, rows)):
            if let placeholder = tailView as? PlaceholderBlockView {
                placeholder.configureTable(header: header, rowCount: rows.count)
            }
        default:
            if let textFlowView = tailView as? TextFlowView,
               let attributed = makeFlowAttributedString(from: frozenBlock) {
                textFlowView.configure(with: attributed)
            }
        }

        if let textFlowView = tailView as? TextFlowView {
            textFlowView.finishReveal()
        }
    }
}

private extension TailPromotionController {
    static func checkFlowCompatibility(tail: Block, frozen: Block) -> Bool {
        guard let tailFlow = makeFlowAttributedString(from: tail)?.string,
              let frozenFlow = makeFlowAttributedString(from: frozen)?.string else { return false }

        let tailText = tailFlow.trimmingCharacters(in: .whitespacesAndNewlines)
        let frozenText = frozenFlow.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tailText.isEmpty == false, frozenText.isEmpty == false else { return false }

        guard frozenText.hasPrefix(tailText) || tailText.hasPrefix(frozenText) else {
            return false
        }

        let overlapLength = min(tailText.count, frozenText.count)
        return overlapLength >= 12 || tailText == frozenText
    }

    static func makeFlowAttributedString(from block: Block) -> NSAttributedString? {
        let nodes = FlowSegmentBuilder.build(from: [block])
        guard case let .flow(segment) = nodes.first else {
            return nil
        }

        return AttributedStringBuilder.build(from: segment)
    }
}
