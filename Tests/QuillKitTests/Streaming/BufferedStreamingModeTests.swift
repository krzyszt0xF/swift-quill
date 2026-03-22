import QuillCore
@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("Buffered Streaming Mode")
struct BufferedStreamingModeTests {
    @Test("Buffered mode avoids tiny first commit before safe threshold")
    func avoidsTinyFirstCommit() async throws {
        let view = makeBufferedModulesQuillView(minModuleLength: 180, maxBufferingDelay: 0.2)

        view.append(String(repeating: "a", count: 150))
        await wait(for: .milliseconds(280))
        #expect(documentHasContent(view) == false)

        view.append(String(repeating: "b", count: 220) + "\n\n")
        let renderedContent = await eventually(timeout: .seconds(1.2)) {
            documentHasContent(view)
        }

        #expect(renderedContent)
    }

    @Test("Buffered mode with slow chunks waits for larger module commit")
    func slowChunksPreferLargerCommit() async throws {
        let view = makeBufferedModulesQuillView(minModuleLength: 180, maxBufferingDelay: 4.0)

        view.append(String(repeating: "x", count: 60))
        await wait(for: .milliseconds(420))
        #expect(documentHasContent(view) == false)

        view.append(String(repeating: "y", count: 60))
        await wait(for: .milliseconds(420))
        #expect(documentHasContent(view) == false)

        view.append(String(repeating: "z", count: 60))
        await wait(for: .milliseconds(420))
        #expect(documentHasContent(view) == false)

        view.append(String(repeating: "k", count: 220) + "\n\n")
        let renderedContent = await eventually(timeout: .seconds(1.2)) {
            documentHasContent(view)
        }

        #expect(renderedContent)
    }
}
