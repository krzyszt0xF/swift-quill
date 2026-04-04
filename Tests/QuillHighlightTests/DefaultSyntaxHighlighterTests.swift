@testable import QuillHighlight
import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@Suite("SyntaxHighlighter", .tags(.rendering))
struct SyntaxHighlighterTests {
    static let aliasCases: [SyntaxHighlighterAliasCase] = [
        .init(code: "const x = 1", language: "js", name: "JavaScript alias"),
        .init(code: "x = 1", language: "py", name: "Python alias"),
        .init(code: "const x: number = 1", language: "ts", name: "TypeScript alias"),
    ]

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

    @Test("language aliases resolve to highlighted results", arguments: aliasCases)
    func languageAliasesResolve(_ testCase: SyntaxHighlighterAliasCase) {
        let result = QuillHighlight.SyntaxHighlighter.default.highlight(
            code: testCase.code,
            language: testCase.language
        )
        #expect(result != nil)
    }

    @Test("concurrent calls do not crash")
    func concurrentCallsDoNotCrash() async {
        let highlighter = QuillHighlight.SyntaxHighlighter.default

        let allHighlighted = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for i in 0..<10 {
                group.addTask {
                    highlighter.highlight(code: "let value = \(i)", language: "swift") != nil
                }
            }

            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        #expect(allHighlighted.allSatisfy { $0 })
    }
}

struct SyntaxHighlighterAliasCase: Sendable {
    let code: String
    let language: String
    let name: String
}

extension SyntaxHighlighterAliasCase: CustomTestStringConvertible {
    var testDescription: String { name }
}
