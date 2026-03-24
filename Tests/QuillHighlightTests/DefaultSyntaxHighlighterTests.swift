@testable import QuillHighlight
import QuillKit
import Testing
import UIKit

@Suite("SyntaxHighlighter")
struct SyntaxHighlighterTests {

    @Test("default singleton returns result for known language")
    func defaultSingletonReturnsResultForKnownLanguage() {
        let result = QuillHighlight.SyntaxHighlighter.default.highlight(code: "let x = 1", language: "swift")
        #expect(result != nil)
    }

    @Test("known language returns highlighted result")
    func knownLanguageReturnsHighlightedResult() {
        let result = QuillHighlight.SyntaxHighlighter.default.highlight(code: "let x = 1", language: "swift")
        #expect(result != nil)
        #expect(result?.string.contains("let x = 1") == true)
    }

    @Test("garbage language returns nil")
    func garbageLanguageReturnsNil() {
        let result = QuillHighlight.SyntaxHighlighter.default.highlight(code: "some code", language: "xyznotreal")
        #expect(result == nil)
    }

    @Test("js alias resolves to JavaScript")
    func jsAliasResolvesToJavaScript() {
        let result = QuillHighlight.SyntaxHighlighter.default.highlight(code: "const x = 1", language: "js")
        #expect(result != nil)
    }

    @Test("py alias resolves to Python")
    func pyAliasResolvesToPython() {
        let result = QuillHighlight.SyntaxHighlighter.default.highlight(code: "x = 1", language: "py")
        #expect(result != nil)
    }

    @Test("ts alias resolves to TypeScript")
    func tsAliasResolvesToTypeScript() {
        let result = QuillHighlight.SyntaxHighlighter.default.highlight(code: "const x: number = 1", language: "ts")
        #expect(result != nil)
    }

    @Test("concurrent calls do not crash")
    func concurrentCallsDoNotCrash() async {
        let highlighter = QuillHighlight.SyntaxHighlighter.default

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    _ = highlighter.highlight(code: "let value = \(i)", language: "swift")
                }
            }
        }
    }
}
