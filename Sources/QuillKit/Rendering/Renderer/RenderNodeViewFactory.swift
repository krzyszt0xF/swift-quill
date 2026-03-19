import QuillCore
import UIKit

@MainActor
struct RenderNodeViewFactory {
    var makeView: (RenderNode) -> UIView
}

extension RenderNodeViewFactory {
    static let live = RenderNodeViewFactory { node in
        switch node {
        case let .codeBlock(language, code):
            let view = CodeBlockView()
            view.configure(language: language, code: code)
            return view
        case let .flow(segment):
            let view = TextFlowView()
            view.configure(with: AttributedStringBuilder.build(from: segment))
            return view
        case let .image(_, title):
            return PlaceholderBlockView.image(title: title)
        case let .table(_, header, rows):
            return PlaceholderBlockView.table(header: header, rowCount: rows.count)
        }
    }
}
