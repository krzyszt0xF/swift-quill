import QuillCore

struct ImageBlockContent: Sendable {
    let alt: String
    let blockID: BlockIdentity
    let source: String?
}

extension ImageBlockContent {
    init(from attachment: ImageAttachment) {
        self.init(
            alt: attachment.alt,
            blockID: attachment.blockID,
            source: attachment.source
        )
    }
}
