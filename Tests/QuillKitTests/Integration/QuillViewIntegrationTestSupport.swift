import Foundation

private let largeMarkdownSectionCount = 10

let quillIntegrationMixedMarkdownFixture = """
# Integration Test Heading

A paragraph with **bold** and *italic* formatting.

- First item
- Second item
- Third item

```swift
let code = "example"
print(code)
```

> A blockquote with some wisdom.

---

| Column A | Column B |
|----------|----------|
| Cell 1   | Cell 2   |
| Cell 3   | Cell 4   |

Final paragraph to close out the fixture.

"""

func makeQuillIntegrationLargeMarkdown() -> String {
    var markdown = "# Large Document\n\n"
    for sectionIndex in 1...largeMarkdownSectionCount {
        markdown += "## Section \(sectionIndex)\n\n"
        markdown += "This is paragraph content for section \(sectionIndex). "
            + "It contains enough text to contribute meaningfully to the total character count of the document.\n\n"
        markdown += "- Item \(sectionIndex)a with some detail\n"
            + "- Item \(sectionIndex)b with more detail\n"
            + "- Item \(sectionIndex)c with even more detail\n\n"
    }
    markdown += "```\nfinal code block content\nwith multiple lines\n```\n\n"
    return markdown
}
