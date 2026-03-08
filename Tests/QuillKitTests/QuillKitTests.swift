import QuillKit
import Testing

@Test func quillKitDependencyChain() {
    // Verifies QuillKit correctly depends on QuillCore.
    #expect(QuillKit.coreVersion == "0.1.0")
}
