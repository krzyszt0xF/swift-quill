import QuillCore

struct CodeBlockContent: Sendable {
    let blockID: BlockIdentity
    let code: String
    let language: String?
}

extension CodeBlockContent {
    init(from attachment: CodeBlockAttachment) {
        self.init(
            blockID: attachment.blockID,
            code: attachment.code,
            language: attachment.language
        )
    }
}
