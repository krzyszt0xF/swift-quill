import Testing
import QuillKit

@Test func quillKitDependencyChain() {
    // Verifies QuillKit correctly depends on QuillCore.
    #expect(QuillKit.coreVersion == "0.1.0")
}
