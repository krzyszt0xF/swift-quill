import QuillSwiftUI
import Testing

@Test func quillSwiftUIDependencyChain() {
    // Verifies QuillSwiftUI -> QuillKit -> QuillCore chain.
    #expect(QuillSwiftUI.kitVersion == "0.1.0")
}
