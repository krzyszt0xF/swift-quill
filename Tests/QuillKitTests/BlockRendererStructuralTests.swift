import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("BlockRenderer Structural")
struct BlockRendererStructuralTests {
    @Test("Code block markdown produces CodeBlockView")
    func codeBlockProducesCodeBlockView() {
        let markdown = """
        ```swift
        let x = 1
        ```
        """
        let stack = BlockRenderer.render(markdown: markdown) as! UIStackView
        let hasCodeBlock = stack.arrangedSubviews.contains { $0 is CodeBlockView }
        #expect(hasCodeBlock)
    }

    @Test("Flow-code-flow produces correct view sequence")
    func flowCodeFlowSequence() {
        let markdown = "paragraph\n\n```swift\ncode\n```\n\nparagraph"
        let stack = BlockRenderer.render(markdown: markdown) as! UIStackView
        let types = stack.arrangedSubviews.map { type(of: $0) }

        #expect(types.count == 3)
        #expect(types[0] == TextFlowView.self)
        #expect(types[1] == CodeBlockView.self)
        #expect(types[2] == TextFlowView.self)
    }

    @Test("Table markdown produces PlaceholderBlockView")
    func tableProducesPlaceholder() {
        let markdown = "| Name | Age | City |\n|------|-----|------|\n| Alice | 30 | NYC |\n| Bob | 25 | LA |"
        let stack = BlockRenderer.render(markdown: markdown) as! UIStackView
        let hasPlaceholder = stack.arrangedSubviews.contains { $0 is PlaceholderBlockView }
        #expect(hasPlaceholder)
    }

    @Test("Mixed structural and flow produces correct sequence")
    func mixedStructuralAndFlow() {
        let markdown = "intro paragraph\n\n```swift\nlet x = 1\n```\n\nmiddle paragraph\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\nclosing paragraph"
        let stack = BlockRenderer.render(markdown: markdown) as! UIStackView
        let types = stack.arrangedSubviews.map { type(of: $0) }

        #expect(types.count == 5)
        #expect(types[0] == TextFlowView.self)
        #expect(types[1] == CodeBlockView.self)
        #expect(types[2] == TextFlowView.self)
        #expect(types[3] == PlaceholderBlockView.self)
        #expect(types[4] == TextFlowView.self)
    }

    @Test("PlaceholderBlockView table shows dimensions text")
    func tablePlaceholderShowsDimensions() {
        let header = Block.TableRow(cells: [
            Block.TableCell(content: [.text("Name")]),
            Block.TableCell(content: [.text("Age")]),
            Block.TableCell(content: [.text("City")]),
        ])
        let view = PlaceholderBlockView.table(header: header, rowCount: 4)
        let label = findSubview(of: UILabel.self, in: view)
        #expect(label?.text?.contains("3x5") == true)
    }
}

private extension BlockRendererStructuralTests {
    func findSubview<T: UIView>(of type: T.Type, in view: UIView, matching predicate: ((T) -> Bool)? = nil) -> T? {
        for subview in view.subviews {
            if let match = subview as? T, predicate?(match) ?? true {
                return match
            }
            if let found = findSubview(of: type, in: subview, matching: predicate) {
                return found
            }
        }
        return nil
    }
}
