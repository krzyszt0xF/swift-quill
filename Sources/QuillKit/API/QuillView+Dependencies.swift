import QuillCore

extension QuillView {
    package struct Dependencies {
        var heightCoordinator: HeightCoordinator
        var markdownParser: MarkdownParser
        var streamCoordinator: StreamCoordinator
    }
}

package extension QuillView.Dependencies {
    @MainActor
    static var live: Self {
        Self(
            heightCoordinator: HeightCoordinator(),
            markdownParser: .live,
            streamCoordinator: .live)
    }
}
