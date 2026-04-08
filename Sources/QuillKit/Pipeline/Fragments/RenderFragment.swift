import QuillCore
import UIKit

struct RenderFragment {
    let attributedString: NSAttributedString
    let blockquoteDepth: Int
    let contentBlockID: BlockIdentity
    let ownerBlockID: BlockIdentity
    let presentationRole: PresentationRole
}

extension RenderFragment {
    enum PresentationRole: String {
        case fullWidthEmbeddedBlock
        case indentedListBlock
        case indentedListText
        case regularBlock
        case standaloneListMarker
    }
}

extension NSAttributedString.Key {
    static let attachmentPlainText = NSAttributedString.Key("quill.attachmentPlainText")
    static let blockquoteDepth = NSAttributedString.Key("quill.blockquoteDepth")
    static let contentBlockID = NSAttributedString.Key("quill.contentBlockID")
    static let ownerBlockID = NSAttributedString.Key("quill.ownerBlockID")
    static let structuralMarker = NSAttributedString.Key("quill.structuralMarker")
}
