import os

enum QuillSignpost {
    static let subsystem = "com.quill.pipeline"
    static let enrichment = OSSignposter(subsystem: subsystem, category: "Enrichment")
    static let height = OSSignposter(subsystem: subsystem, category: "Height")
    static let parse = OSSignposter(subsystem: subsystem, category: "Parse")
    static let reduce = OSSignposter(subsystem: subsystem, category: "Reduce")
    static let render = OSSignposter(subsystem: subsystem, category: "Render")
}
