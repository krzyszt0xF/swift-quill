import XCTest

func loadFixture(
    named name: String,
    file: StaticString = #file,
    line: UInt = #line
) -> String {
    guard let url = Bundle.module.url(
        forResource: name,
        withExtension: "md",
        subdirectory: "Fixtures"
    ) else {
        XCTFail("Missing fixture: \(name).md", file: file, line: line)
        return ""
    }
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        XCTFail("Failed to load fixture \(name).md: \(error)", file: file, line: line)
        return ""
    }
}
