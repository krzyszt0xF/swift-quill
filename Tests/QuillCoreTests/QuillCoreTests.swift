import Testing
import QuillCore

@Test func quillCoreIsAccessible() {
    // This test running via `swift test` proves ARCH-01:
    // QuillCore has zero UIKit dependencies.
    // `swift test` builds for macOS where UIKit is unavailable.
    #expect(QuillCore.version == "0.1.0")
}
